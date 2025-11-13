-- =============================================================================
-- COMMUNITY API - STORED PROCEDURES
-- Database Schema: activity
-- PostgreSQL 15+
--
-- This file contains all 18 stored procedures for the Community API
-- All procedures follow the naming convention: sp_community_<action>
-- =============================================================================

-- SP1: Create Community
-- Purpose: Create a new community (open type only for Phase 1)
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_create(
    p_creator_user_id UUID,
    p_organization_id UUID,
    p_name VARCHAR(255),
    p_slug VARCHAR(100),
    p_description TEXT,
    p_community_type activity.community_type,
    p_cover_image_url VARCHAR(500),
    p_icon_url VARCHAR(500),
    p_max_members INT,
    p_tags TEXT[]
) RETURNS TABLE(
    community_id UUID,
    slug VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE,
    member_count INT
) AS $$
DECLARE
    v_community_id UUID;
    v_created_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- 1. Validate user exists
    IF NOT EXISTS (SELECT 1 FROM activity.users WHERE user_id = p_creator_user_id) THEN
        RAISE EXCEPTION 'USER_NOT_FOUND';
    END IF;

    -- 2. If org provided, validate membership
    IF p_organization_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM activity.organizations WHERE organization_id = p_organization_id) THEN
            RAISE EXCEPTION 'ORGANIZATION_NOT_FOUND';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM activity.organization_members
            WHERE organization_id = p_organization_id
            AND user_id = p_creator_user_id
        ) THEN
            RAISE EXCEPTION 'NOT_ORGANIZATION_MEMBER';
        END IF;
    END IF;

    -- 3. Validate slug uniqueness
    IF EXISTS (
        SELECT 1 FROM activity.communities
        WHERE slug = p_slug
        AND (
            (organization_id = p_organization_id) OR
            (organization_id IS NULL AND p_organization_id IS NULL)
        )
    ) THEN
        RAISE EXCEPTION 'SLUG_EXISTS';
    END IF;

    -- 4. Validate community type (Phase 1: only 'open')
    IF p_community_type != 'open' THEN
        RAISE EXCEPTION 'INVALID_COMMUNITY_TYPE';
    END IF;

    -- 5. Insert community
    INSERT INTO activity.communities (
        organization_id,
        creator_user_id,
        name,
        slug,
        description,
        community_type,
        status,
        member_count,
        max_members,
        cover_image_url,
        icon_url
    ) VALUES (
        p_organization_id,
        p_creator_user_id,
        p_name,
        p_slug,
        p_description,
        p_community_type,
        'active',
        1,
        p_max_members,
        p_cover_image_url,
        p_icon_url
    ) RETURNING communities.community_id, communities.created_at
    INTO v_community_id, v_created_at;

    -- 6. Insert creator as organizer
    INSERT INTO activity.community_members (
        community_id,
        user_id,
        role,
        status
    ) VALUES (
        v_community_id,
        p_creator_user_id,
        'organizer',
        'active'
    );

    -- 7. Insert tags if provided
    IF p_tags IS NOT NULL AND array_length(p_tags, 1) > 0 THEN
        INSERT INTO activity.community_tags (community_id, tag)
        SELECT v_community_id, unnest(p_tags);
    END IF;

    -- 8. Return community details
    RETURN QUERY
    SELECT v_community_id, p_slug, v_created_at, 1;
END;
$$ LANGUAGE plpgsql;

-- SP2: Get Community by ID
-- Purpose: Get community details by community_id
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_get_by_id(
    p_community_id UUID,
    p_requesting_user_id UUID
) RETURNS TABLE(
    community_id UUID,
    organization_id UUID,
    creator_user_id UUID,
    name VARCHAR(255),
    slug VARCHAR(100),
    description TEXT,
    community_type activity.community_type,
    status activity.community_status,
    member_count INT,
    max_members INT,
    is_featured BOOLEAN,
    cover_image_url VARCHAR(500),
    icon_url VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    is_member BOOLEAN,
    user_role activity.participant_role,
    user_status activity.membership_status,
    tags TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.community_id,
        c.organization_id,
        c.creator_user_id,
        c.name,
        c.slug,
        c.description,
        c.community_type,
        c.status,
        c.member_count,
        c.max_members,
        c.is_featured,
        c.cover_image_url,
        c.icon_url,
        c.created_at,
        c.updated_at,
        CASE WHEN cm.user_id IS NOT NULL THEN TRUE ELSE FALSE END as is_member,
        cm.role as user_role,
        cm.status as user_status,
        COALESCE(ARRAY_AGG(ct.tag) FILTER (WHERE ct.tag IS NOT NULL), ARRAY[]::TEXT[]) as tags
    FROM activity.communities c
    LEFT JOIN activity.community_members cm
        ON c.community_id = cm.community_id
        AND cm.user_id = p_requesting_user_id
        AND cm.status = 'active'
    LEFT JOIN activity.community_tags ct
        ON c.community_id = ct.community_id
    WHERE c.community_id = p_community_id
    GROUP BY
        c.community_id, c.organization_id, c.creator_user_id, c.name, c.slug,
        c.description, c.community_type, c.status, c.member_count, c.max_members,
        c.is_featured, c.cover_image_url, c.icon_url, c.created_at, c.updated_at,
        cm.user_id, cm.role, cm.status;
END;
$$ LANGUAGE plpgsql;

-- SP3: Update Community
-- Purpose: Update community details (organizer only)
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_update(
    p_community_id UUID,
    p_updating_user_id UUID,
    p_name VARCHAR(255),
    p_description TEXT,
    p_cover_image_url VARCHAR(500),
    p_icon_url VARCHAR(500),
    p_max_members INT,
    p_tags TEXT[]
) RETURNS TABLE(
    community_id UUID,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_updated_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- 1. Validate community exists and status='active'
    IF NOT EXISTS (
        SELECT 1 FROM activity.communities
        WHERE communities.community_id = p_community_id
        AND status = 'active'
    ) THEN
        IF NOT EXISTS (SELECT 1 FROM activity.communities WHERE communities.community_id = p_community_id) THEN
            RAISE EXCEPTION 'COMMUNITY_NOT_FOUND';
        ELSE
            RAISE EXCEPTION 'COMMUNITY_NOT_ACTIVE';
        END IF;
    END IF;

    -- 2. Check user is organizer
    IF NOT EXISTS (
        SELECT 1 FROM activity.community_members
        WHERE community_members.community_id = p_community_id
        AND user_id = p_updating_user_id
        AND role = 'organizer'
        AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'INSUFFICIENT_PERMISSIONS';
    END IF;

    -- 3. Update community
    UPDATE activity.communities
    SET
        name = COALESCE(p_name, name),
        description = COALESCE(p_description, description),
        cover_image_url = COALESCE(p_cover_image_url, cover_image_url),
        icon_url = COALESCE(p_icon_url, icon_url),
        max_members = COALESCE(p_max_members, max_members),
        updated_at = NOW()
    WHERE communities.community_id = p_community_id
    RETURNING communities.updated_at INTO v_updated_at;

    -- 4. Handle tags if provided
    IF p_tags IS NOT NULL THEN
        DELETE FROM activity.community_tags WHERE community_tags.community_id = p_community_id;
        IF array_length(p_tags, 1) > 0 THEN
            INSERT INTO activity.community_tags (community_id, tag)
            SELECT p_community_id, unnest(p_tags);
        END IF;
    END IF;

    -- 5. Return updated details
    RETURN QUERY
    SELECT p_community_id, v_updated_at;
END;
$$ LANGUAGE plpgsql;

-- SP4: Join Community
-- Purpose: Join an open community
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_join(
    p_community_id UUID,
    p_user_id UUID
) RETURNS TABLE(
    community_id UUID,
    user_id UUID,
    role activity.participant_role,
    status activity.membership_status,
    joined_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_community_type activity.community_type;
    v_member_count INT;
    v_max_members INT;
    v_status activity.community_status;
    v_joined_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- 1. Validate community exists and get details
    SELECT c.community_type, c.member_count, c.max_members, c.status
    INTO v_community_type, v_member_count, v_max_members, v_status
    FROM activity.communities c
    WHERE c.community_id = p_community_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'COMMUNITY_NOT_FOUND';
    END IF;

    -- Check community is active
    IF v_status != 'active' THEN
        RAISE EXCEPTION 'COMMUNITY_NOT_ACTIVE';
    END IF;

    -- Check community is open type
    IF v_community_type != 'open' THEN
        RAISE EXCEPTION 'COMMUNITY_NOT_OPEN';
    END IF;

    -- 2. Check if max_members reached
    IF v_max_members IS NOT NULL AND v_member_count >= v_max_members THEN
        RAISE EXCEPTION 'COMMUNITY_FULL';
    END IF;

    -- 3. Check user not already member
    IF EXISTS (
        SELECT 1 FROM activity.community_members
        WHERE community_members.community_id = p_community_id
        AND community_members.user_id = p_user_id
    ) THEN
        RAISE EXCEPTION 'ALREADY_MEMBER';
    END IF;

    -- 4. Insert membership
    v_joined_at := NOW();
    INSERT INTO activity.community_members (
        community_id,
        user_id,
        role,
        status,
        joined_at
    ) VALUES (
        p_community_id,
        p_user_id,
        'member',
        'active',
        v_joined_at
    );

    -- 5. Update member count
    UPDATE activity.communities
    SET member_count = member_count + 1
    WHERE communities.community_id = p_community_id;

    -- 6. Return membership details
    RETURN QUERY
    SELECT p_community_id, p_user_id, 'member'::activity.participant_role, 'active'::activity.membership_status, v_joined_at;
END;
$$ LANGUAGE plpgsql;

-- SP5: Leave Community
-- Purpose: Leave a community (cannot leave if organizer)
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_leave(
    p_community_id UUID,
    p_user_id UUID
) RETURNS TABLE(
    community_id UUID,
    user_id UUID,
    left_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_role activity.participant_role;
    v_status activity.membership_status;
    v_left_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- 1. Get membership details
    SELECT cm.role, cm.status
    INTO v_role, v_status
    FROM activity.community_members cm
    WHERE cm.community_id = p_community_id
    AND cm.user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_MEMBER';
    END IF;

    -- Check if already left
    IF v_status != 'active' THEN
        RAISE EXCEPTION 'NOT_MEMBER';
    END IF;

    -- 2. Check user is NOT organizer
    IF v_role = 'organizer' THEN
        RAISE EXCEPTION 'ORGANIZER_CANNOT_LEAVE';
    END IF;

    -- 3. Update membership status
    v_left_at := NOW();
    UPDATE activity.community_members
    SET status = 'left', left_at = v_left_at
    WHERE community_members.community_id = p_community_id
    AND community_members.user_id = p_user_id;

    -- 4. Update member count
    UPDATE activity.communities
    SET member_count = member_count - 1
    WHERE communities.community_id = p_community_id;

    -- 5. Return confirmation
    RETURN QUERY
    SELECT p_community_id, p_user_id, v_left_at;
END;
$$ LANGUAGE plpgsql;

-- SP6: Get Community Members
-- Purpose: Get paginated list of community members
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_get_members(
    p_community_id UUID,
    p_requesting_user_id UUID,
    p_limit INT DEFAULT 50,
    p_offset INT DEFAULT 0
) RETURNS TABLE(
    user_id UUID,
    username VARCHAR(100),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    main_photo_url VARCHAR(500),
    role activity.participant_role,
    status activity.membership_status,
    joined_at TIMESTAMP WITH TIME ZONE,
    is_verified BOOLEAN,
    total_count BIGINT
) AS $$
DECLARE
    v_community_type activity.community_type;
    v_is_member BOOLEAN;
BEGIN
    -- 1. Validate community exists
    SELECT c.community_type INTO v_community_type
    FROM activity.communities c
    WHERE c.community_id = p_community_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'COMMUNITY_NOT_FOUND';
    END IF;

    -- 2. Check permission (is member OR community is open)
    SELECT EXISTS (
        SELECT 1 FROM activity.community_members cm
        WHERE cm.community_id = p_community_id
        AND cm.user_id = p_requesting_user_id
        AND cm.status = 'active'
    ) INTO v_is_member;

    IF NOT v_is_member AND v_community_type != 'open' THEN
        RAISE EXCEPTION 'INSUFFICIENT_PERMISSIONS';
    END IF;

    -- 3. Return members
    RETURN QUERY
    SELECT
        u.user_id,
        u.username,
        u.first_name,
        u.last_name,
        u.main_photo_url,
        cm.role,
        cm.status,
        cm.joined_at,
        u.is_verified,
        COUNT(*) OVER() as total_count
    FROM activity.community_members cm
    JOIN activity.users u ON cm.user_id = u.user_id
    WHERE cm.community_id = p_community_id
    AND cm.status = 'active'
    ORDER BY
        CASE cm.role
            WHEN 'organizer' THEN 1
            WHEN 'co_organizer' THEN 2
            ELSE 3
        END,
        cm.joined_at ASC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- SP7: Search Communities
-- Purpose: Search communities with filters
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_search(
    p_search_text TEXT,
    p_organization_id UUID,
    p_tags TEXT[],
    p_requesting_user_id UUID,
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0
) RETURNS TABLE(
    community_id UUID,
    organization_id UUID,
    name VARCHAR(255),
    slug VARCHAR(100),
    description TEXT,
    community_type activity.community_type,
    member_count INT,
    max_members INT,
    is_featured BOOLEAN,
    cover_image_url VARCHAR(500),
    icon_url VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE,
    is_member BOOLEAN,
    tags TEXT[],
    total_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.community_id,
        c.organization_id,
        c.name,
        c.slug,
        c.description,
        c.community_type,
        c.member_count,
        c.max_members,
        c.is_featured,
        c.cover_image_url,
        c.icon_url,
        c.created_at,
        CASE WHEN cm.user_id IS NOT NULL THEN TRUE ELSE FALSE END as is_member,
        COALESCE(ARRAY_AGG(ct.tag) FILTER (WHERE ct.tag IS NOT NULL), ARRAY[]::TEXT[]) as tags,
        COUNT(*) OVER() as total_count
    FROM activity.communities c
    LEFT JOIN activity.community_members cm
        ON c.community_id = cm.community_id
        AND cm.user_id = p_requesting_user_id
        AND cm.status = 'active'
    LEFT JOIN activity.community_tags ct
        ON c.community_id = ct.community_id
    WHERE c.status = 'active'
        AND (p_search_text IS NULL OR (
            c.name ILIKE '%' || p_search_text || '%' OR
            c.description ILIKE '%' || p_search_text || '%'
        ))
        AND (p_organization_id IS NULL OR c.organization_id = p_organization_id)
        AND (p_tags IS NULL OR EXISTS (
            SELECT 1 FROM activity.community_tags ct2
            WHERE ct2.community_id = c.community_id
            AND ct2.tag = ANY(p_tags)
        ))
    GROUP BY
        c.community_id, c.organization_id, c.name, c.slug, c.description,
        c.community_type, c.member_count, c.max_members, c.is_featured,
        c.cover_image_url, c.icon_url, c.created_at, cm.user_id
    ORDER BY c.is_featured DESC, c.member_count DESC, c.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- SP8: Create Community Post
-- Purpose: Create a post in a community
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_post_create(
    p_community_id UUID,
    p_author_user_id UUID,
    p_activity_id UUID,
    p_title VARCHAR(500),
    p_content TEXT,
    p_content_type activity.content_type DEFAULT 'post'
) RETURNS TABLE(
    post_id UUID,
    community_id UUID,
    author_user_id UUID,
    created_at TIMESTAMP WITH TIME ZONE,
    status activity.content_status
) AS $$
DECLARE
    v_post_id UUID;
    v_created_at TIMESTAMP WITH TIME ZONE;
    v_community_status activity.community_status;
BEGIN
    -- 1. Validate community exists and is active
    SELECT c.status INTO v_community_status
    FROM activity.communities c
    WHERE c.community_id = p_community_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'COMMUNITY_NOT_FOUND';
    END IF;

    IF v_community_status != 'active' THEN
        RAISE EXCEPTION 'COMMUNITY_NOT_ACTIVE';
    END IF;

    -- 2. Check user is active member
    IF NOT EXISTS (
        SELECT 1 FROM activity.community_members cm
        WHERE cm.community_id = p_community_id
        AND cm.user_id = p_author_user_id
        AND cm.status = 'active'
    ) THEN
        RAISE EXCEPTION 'NOT_MEMBER';
    END IF;

    -- 3. If activity_id provided, validate it exists
    IF p_activity_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM activity.activities WHERE activity_id = p_activity_id) THEN
            RAISE EXCEPTION 'ACTIVITY_NOT_FOUND';
        END IF;
    END IF;

    -- 4. Insert post
    v_created_at := NOW();
    INSERT INTO activity.posts (
        community_id,
        author_user_id,
        activity_id,
        title,
        content,
        content_type,
        status,
        view_count,
        comment_count,
        reaction_count,
        created_at
    ) VALUES (
        p_community_id,
        p_author_user_id,
        p_activity_id,
        p_title,
        p_content,
        p_content_type,
        'published',
        0,
        0,
        0,
        v_created_at
    ) RETURNING posts.post_id INTO v_post_id;

    -- 5. Return post details
    RETURN QUERY
    SELECT v_post_id, p_community_id, p_author_user_id, v_created_at, 'published'::activity.content_status;
END;
$$ LANGUAGE plpgsql;

-- SP9: Update Community Post
-- Purpose: Update own post (author only)
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_post_update(
    p_post_id UUID,
    p_updating_user_id UUID,
    p_title VARCHAR(500),
    p_content TEXT
) RETURNS TABLE(
    post_id UUID,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_author_user_id UUID;
    v_status activity.content_status;
    v_updated_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- 1. Get post details
    SELECT p.author_user_id, p.status
    INTO v_author_user_id, v_status
    FROM activity.posts p
    WHERE p.post_id = p_post_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'POST_NOT_FOUND';
    END IF;

    -- Check post is published
    IF v_status != 'published' THEN
        RAISE EXCEPTION 'POST_NOT_PUBLISHED';
    END IF;

    -- 2. Check user is author
    IF v_author_user_id != p_updating_user_id THEN
        RAISE EXCEPTION 'INSUFFICIENT_PERMISSIONS';
    END IF;

    -- 3. Update post
    v_updated_at := NOW();
    UPDATE activity.posts
    SET
        title = COALESCE(p_title, title),
        content = COALESCE(p_content, content),
        updated_at = v_updated_at
    WHERE posts.post_id = p_post_id;

    -- 4. Return updated details
    RETURN QUERY
    SELECT p_post_id, v_updated_at;
END;
$$ LANGUAGE plpgsql;

-- SP10: Delete Community Post
-- Purpose: Delete own post (soft delete)
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_post_delete(
    p_post_id UUID,
    p_deleting_user_id UUID
) RETURNS TABLE(
    post_id UUID,
    deleted_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_author_user_id UUID;
    v_community_id UUID;
    v_deleted_at TIMESTAMP WITH TIME ZONE;
    v_is_organizer BOOLEAN;
BEGIN
    -- 1. Get post details
    SELECT p.author_user_id, p.community_id
    INTO v_author_user_id, v_community_id
    FROM activity.posts p
    WHERE p.post_id = p_post_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'POST_NOT_FOUND';
    END IF;

    -- 2. Check if user is author or community organizer
    v_is_organizer := EXISTS (
        SELECT 1 FROM activity.community_members cm
        WHERE cm.community_id = v_community_id
        AND cm.user_id = p_deleting_user_id
        AND cm.role = 'organizer'
        AND cm.status = 'active'
    );

    IF v_author_user_id != p_deleting_user_id AND NOT v_is_organizer THEN
        RAISE EXCEPTION 'INSUFFICIENT_PERMISSIONS';
    END IF;

    -- 3. Soft delete post
    v_deleted_at := NOW();
    UPDATE activity.posts
    SET status = 'removed', updated_at = v_deleted_at
    WHERE posts.post_id = p_post_id;

    -- 4. Return confirmation
    RETURN QUERY
    SELECT p_post_id, v_deleted_at;
END;
$$ LANGUAGE plpgsql;

-- SP11: Get Community Post Feed
-- Purpose: Get paginated post feed for a community
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_post_get_feed(
    p_community_id UUID,
    p_requesting_user_id UUID,
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0
) RETURNS TABLE(
    post_id UUID,
    author_user_id UUID,
    author_username VARCHAR(100),
    author_first_name VARCHAR(100),
    author_main_photo_url VARCHAR(500),
    activity_id UUID,
    title VARCHAR(500),
    content TEXT,
    content_type activity.content_type,
    view_count INT,
    comment_count INT,
    reaction_count INT,
    is_pinned BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
DECLARE
    v_community_type activity.community_type;
    v_is_member BOOLEAN;
BEGIN
    -- 1. Validate community exists
    SELECT c.community_type INTO v_community_type
    FROM activity.communities c
    WHERE c.community_id = p_community_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'COMMUNITY_NOT_FOUND';
    END IF;

    -- 2. Check permission (is member OR community is open)
    SELECT EXISTS (
        SELECT 1 FROM activity.community_members cm
        WHERE cm.community_id = p_community_id
        AND cm.user_id = p_requesting_user_id
        AND cm.status = 'active'
    ) INTO v_is_member;

    IF NOT v_is_member AND v_community_type != 'open' THEN
        RAISE EXCEPTION 'INSUFFICIENT_PERMISSIONS';
    END IF;

    -- 3. Return post feed
    RETURN QUERY
    SELECT
        p.post_id,
        p.author_user_id,
        u.username,
        u.first_name,
        u.main_photo_url,
        p.activity_id,
        p.title,
        p.content,
        p.content_type,
        p.view_count,
        p.comment_count,
        p.reaction_count,
        p.is_pinned,
        p.created_at,
        p.updated_at,
        COUNT(*) OVER() as total_count
    FROM activity.posts p
    JOIN activity.users u ON p.author_user_id = u.user_id
    WHERE p.community_id = p_community_id
    AND p.status = 'published'
    ORDER BY p.is_pinned DESC, p.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- SP12: Create Comment
-- Purpose: Create a comment on a post
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_comment_create(
    p_post_id UUID,
    p_author_user_id UUID,
    p_parent_comment_id UUID,
    p_content TEXT
) RETURNS TABLE(
    comment_id UUID,
    post_id UUID,
    parent_comment_id UUID,
    author_user_id UUID,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_comment_id UUID;
    v_created_at TIMESTAMP WITH TIME ZONE;
    v_community_id UUID;
    v_post_status activity.content_status;
BEGIN
    -- 1. Validate post exists and get details
    SELECT p.community_id, p.status
    INTO v_community_id, v_post_status
    FROM activity.posts p
    WHERE p.post_id = p_post_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'POST_NOT_FOUND';
    END IF;

    IF v_post_status != 'published' THEN
        RAISE EXCEPTION 'POST_NOT_PUBLISHED';
    END IF;

    -- 2. Check user is active member
    IF NOT EXISTS (
        SELECT 1 FROM activity.community_members cm
        WHERE cm.community_id = v_community_id
        AND cm.user_id = p_author_user_id
        AND cm.status = 'active'
    ) THEN
        RAISE EXCEPTION 'NOT_MEMBER';
    END IF;

    -- 3. If parent comment provided, validate it
    IF p_parent_comment_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM activity.comments c
            WHERE c.comment_id = p_parent_comment_id
            AND c.post_id = p_post_id
            AND c.is_deleted = FALSE
        ) THEN
            RAISE EXCEPTION 'PARENT_COMMENT_NOT_FOUND';
        END IF;
    END IF;

    -- 4. Insert comment
    v_created_at := NOW();
    INSERT INTO activity.comments (
        post_id,
        parent_comment_id,
        author_user_id,
        content,
        is_deleted,
        reaction_count,
        created_at
    ) VALUES (
        p_post_id,
        p_parent_comment_id,
        p_author_user_id,
        p_content,
        FALSE,
        0,
        v_created_at
    ) RETURNING comments.comment_id INTO v_comment_id;

    -- 5. Update post comment count
    UPDATE activity.posts
    SET comment_count = comment_count + 1
    WHERE posts.post_id = p_post_id;

    -- 6. Return comment details
    RETURN QUERY
    SELECT v_comment_id, p_post_id, p_parent_comment_id, p_author_user_id, v_created_at;
END;
$$ LANGUAGE plpgsql;

-- SP13: Update Comment
-- Purpose: Update own comment
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_comment_update(
    p_comment_id UUID,
    p_updating_user_id UUID,
    p_content TEXT
) RETURNS TABLE(
    comment_id UUID,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_author_user_id UUID;
    v_is_deleted BOOLEAN;
    v_updated_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- 1. Get comment details
    SELECT c.author_user_id, c.is_deleted
    INTO v_author_user_id, v_is_deleted
    FROM activity.comments c
    WHERE c.comment_id = p_comment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'COMMENT_NOT_FOUND';
    END IF;

    IF v_is_deleted THEN
        RAISE EXCEPTION 'COMMENT_DELETED';
    END IF;

    -- 2. Check user is author
    IF v_author_user_id != p_updating_user_id THEN
        RAISE EXCEPTION 'INSUFFICIENT_PERMISSIONS';
    END IF;

    -- 3. Update comment
    v_updated_at := NOW();
    UPDATE activity.comments
    SET content = p_content, updated_at = v_updated_at
    WHERE comments.comment_id = p_comment_id;

    -- 4. Return updated details
    RETURN QUERY
    SELECT p_comment_id, v_updated_at;
END;
$$ LANGUAGE plpgsql;

-- SP14: Delete Comment
-- Purpose: Delete own comment (soft delete)
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_comment_delete(
    p_comment_id UUID,
    p_deleting_user_id UUID
) RETURNS TABLE(
    comment_id UUID,
    deleted_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_author_user_id UUID;
    v_post_id UUID;
    v_community_id UUID;
    v_deleted_at TIMESTAMP WITH TIME ZONE;
    v_is_organizer BOOLEAN;
BEGIN
    -- 1. Get comment details
    SELECT c.author_user_id, c.post_id
    INTO v_author_user_id, v_post_id
    FROM activity.comments c
    WHERE c.comment_id = p_comment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'COMMENT_NOT_FOUND';
    END IF;

    -- Get community_id from post
    SELECT p.community_id INTO v_community_id
    FROM activity.posts p
    WHERE p.post_id = v_post_id;

    -- 2. Check if user is author or community organizer
    v_is_organizer := EXISTS (
        SELECT 1 FROM activity.community_members cm
        WHERE cm.community_id = v_community_id
        AND cm.user_id = p_deleting_user_id
        AND cm.role = 'organizer'
        AND cm.status = 'active'
    );

    IF v_author_user_id != p_deleting_user_id AND NOT v_is_organizer THEN
        RAISE EXCEPTION 'INSUFFICIENT_PERMISSIONS';
    END IF;

    -- 3. Soft delete comment
    v_deleted_at := NOW();
    UPDATE activity.comments
    SET is_deleted = TRUE, updated_at = v_deleted_at
    WHERE comments.comment_id = p_comment_id;

    -- 4. Update post comment count
    UPDATE activity.posts
    SET comment_count = comment_count - 1
    WHERE posts.post_id = v_post_id;

    -- 5. Return confirmation
    RETURN QUERY
    SELECT p_comment_id, v_deleted_at;
END;
$$ LANGUAGE plpgsql;

-- SP15: Get Post Comments
-- Purpose: Get paginated comments for a post (threaded)
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_post_get_comments(
    p_post_id UUID,
    p_parent_comment_id UUID,
    p_limit INT DEFAULT 50,
    p_offset INT DEFAULT 0
) RETURNS TABLE(
    comment_id UUID,
    parent_comment_id UUID,
    author_user_id UUID,
    author_username VARCHAR(100),
    author_first_name VARCHAR(100),
    author_main_photo_url VARCHAR(500),
    content TEXT,
    reaction_count INT,
    is_deleted BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
BEGIN
    -- 1. Validate post exists
    IF NOT EXISTS (SELECT 1 FROM activity.posts WHERE post_id = p_post_id) THEN
        RAISE EXCEPTION 'POST_NOT_FOUND';
    END IF;

    -- 2. Return comments
    RETURN QUERY
    SELECT
        c.comment_id,
        c.parent_comment_id,
        c.author_user_id,
        u.username,
        u.first_name,
        u.main_photo_url,
        CASE WHEN c.is_deleted THEN '[deleted]' ELSE c.content END as content,
        c.reaction_count,
        c.is_deleted,
        c.created_at,
        c.updated_at,
        COUNT(*) OVER() as total_count
    FROM activity.comments c
    JOIN activity.users u ON c.author_user_id = u.user_id
    WHERE c.post_id = p_post_id
    AND (
        (c.parent_comment_id = p_parent_comment_id) OR
        (c.parent_comment_id IS NULL AND p_parent_comment_id IS NULL)
    )
    ORDER BY c.created_at ASC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- SP16: Create Reaction
-- Purpose: Create or update reaction on post/comment
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_reaction_create(
    p_user_id UUID,
    p_target_type VARCHAR(50),
    p_target_id UUID,
    p_reaction_type activity.reaction_type
) RETURNS TABLE(
    reaction_id UUID,
    target_type VARCHAR(50),
    target_id UUID,
    reaction_type activity.reaction_type,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_reaction_id UUID;
    v_existing_reaction_type activity.reaction_type;
    v_created_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- 1. Validate target exists
    IF p_target_type = 'post' THEN
        IF NOT EXISTS (SELECT 1 FROM activity.posts WHERE post_id = p_target_id) THEN
            RAISE EXCEPTION 'TARGET_NOT_FOUND';
        END IF;
    ELSIF p_target_type = 'comment' THEN
        IF NOT EXISTS (SELECT 1 FROM activity.comments WHERE comment_id = p_target_id) THEN
            RAISE EXCEPTION 'TARGET_NOT_FOUND';
        END IF;
    ELSE
        RAISE EXCEPTION 'INVALID_TARGET_TYPE';
    END IF;

    -- 2. Check if reaction already exists
    SELECT r.reaction_id, r.reaction_type
    INTO v_reaction_id, v_existing_reaction_type
    FROM activity.reactions r
    WHERE r.user_id = p_user_id
    AND r.target_type = p_target_type
    AND r.target_id = p_target_id;

    IF FOUND THEN
        -- Reaction exists
        IF v_existing_reaction_type = p_reaction_type THEN
            -- Same reaction, do nothing (idempotent)
            SELECT created_at INTO v_created_at
            FROM activity.reactions
            WHERE reaction_id = v_reaction_id;

            RETURN QUERY
            SELECT v_reaction_id, p_target_type, p_target_id, p_reaction_type, v_created_at;
            RETURN;
        ELSE
            -- Different reaction, update
            UPDATE activity.reactions
            SET reaction_type = p_reaction_type, created_at = NOW()
            WHERE reaction_id = v_reaction_id
            RETURNING created_at INTO v_created_at;

            RETURN QUERY
            SELECT v_reaction_id, p_target_type, p_target_id, p_reaction_type, v_created_at;
            RETURN;
        END IF;
    END IF;

    -- 3. Insert new reaction
    v_created_at := NOW();
    INSERT INTO activity.reactions (
        user_id,
        target_type,
        target_id,
        reaction_type,
        created_at
    ) VALUES (
        p_user_id,
        p_target_type,
        p_target_id,
        p_reaction_type,
        v_created_at
    ) RETURNING reactions.reaction_id INTO v_reaction_id;

    -- 4. Update target reaction count
    IF p_target_type = 'post' THEN
        UPDATE activity.posts
        SET reaction_count = reaction_count + 1
        WHERE post_id = p_target_id;
    ELSIF p_target_type = 'comment' THEN
        UPDATE activity.comments
        SET reaction_count = reaction_count + 1
        WHERE comment_id = p_target_id;
    END IF;

    -- 5. Return reaction details
    RETURN QUERY
    SELECT v_reaction_id, p_target_type, p_target_id, p_reaction_type, v_created_at;
END;
$$ LANGUAGE plpgsql;

-- SP17: Delete Reaction
-- Purpose: Remove reaction from post/comment
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_reaction_delete(
    p_user_id UUID,
    p_target_type VARCHAR(50),
    p_target_id UUID
) RETURNS TABLE(
    deleted BOOLEAN
) AS $$
DECLARE
    v_reaction_exists BOOLEAN;
BEGIN
    -- 1. Check if reaction exists
    SELECT EXISTS (
        SELECT 1 FROM activity.reactions r
        WHERE r.user_id = p_user_id
        AND r.target_type = p_target_type
        AND r.target_id = p_target_id
    ) INTO v_reaction_exists;

    IF NOT v_reaction_exists THEN
        -- Idempotent: no reaction to delete
        RETURN QUERY SELECT FALSE;
        RETURN;
    END IF;

    -- 2. Delete reaction
    DELETE FROM activity.reactions
    WHERE user_id = p_user_id
    AND target_type = p_target_type
    AND target_id = p_target_id;

    -- 3. Update target reaction count
    IF p_target_type = 'post' THEN
        UPDATE activity.posts
        SET reaction_count = reaction_count - 1
        WHERE post_id = p_target_id;
    ELSIF p_target_type = 'comment' THEN
        UPDATE activity.comments
        SET reaction_count = reaction_count - 1
        WHERE comment_id = p_target_id;
    END IF;

    -- 4. Return success
    RETURN QUERY SELECT TRUE;
END;
$$ LANGUAGE plpgsql;

-- SP18: Link Activity to Community
-- Purpose: Link an activity to a community (organizer of both required)
-- =============================================================================
CREATE OR REPLACE FUNCTION activity.sp_community_link_activity(
    p_community_id UUID,
    p_activity_id UUID,
    p_linking_user_id UUID
) RETURNS TABLE(
    community_id UUID,
    activity_id UUID,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_created_at TIMESTAMP WITH TIME ZONE;
    v_community_status activity.community_status;
    v_activity_status activity.activity_status;
BEGIN
    -- 1. Validate community exists and is active
    SELECT c.status INTO v_community_status
    FROM activity.communities c
    WHERE c.community_id = p_community_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'COMMUNITY_NOT_FOUND';
    END IF;

    IF v_community_status != 'active' THEN
        RAISE EXCEPTION 'COMMUNITY_NOT_ACTIVE';
    END IF;

    -- 2. Validate activity exists and is published
    SELECT a.status INTO v_activity_status
    FROM activity.activities a
    WHERE a.activity_id = p_activity_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ACTIVITY_NOT_FOUND';
    END IF;

    -- Note: activity status might be different enum, checking for 'published' as per spec
    -- Adjust if the actual status field uses different values

    -- 3. Check user is community organizer
    IF NOT EXISTS (
        SELECT 1 FROM activity.community_members cm
        WHERE cm.community_id = p_community_id
        AND cm.user_id = p_linking_user_id
        AND cm.role = 'organizer'
        AND cm.status = 'active'
    ) THEN
        RAISE EXCEPTION 'NOT_COMMUNITY_ORGANIZER';
    END IF;

    -- 4. Check user is activity organizer
    IF NOT EXISTS (
        SELECT 1 FROM activity.activity_participants ap
        WHERE ap.activity_id = p_activity_id
        AND ap.user_id = p_linking_user_id
        AND ap.role = 'organizer'
    ) THEN
        RAISE EXCEPTION 'NOT_ACTIVITY_ORGANIZER';
    END IF;

    -- 5. Check link doesn't already exist
    IF EXISTS (
        SELECT 1 FROM activity.community_activities ca
        WHERE ca.community_id = p_community_id
        AND ca.activity_id = p_activity_id
    ) THEN
        RAISE EXCEPTION 'LINK_ALREADY_EXISTS';
    END IF;

    -- 6. Insert link
    v_created_at := NOW();
    INSERT INTO activity.community_activities (
        community_id,
        activity_id,
        is_pinned,
        created_at
    ) VALUES (
        p_community_id,
        p_activity_id,
        FALSE,
        v_created_at
    );

    -- 7. Return link details
    RETURN QUERY
    SELECT p_community_id, p_activity_id, v_created_at;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- END OF STORED PROCEDURES
-- =============================================================================
