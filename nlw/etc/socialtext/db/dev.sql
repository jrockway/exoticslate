--
-- These are useful views and tricks for debugging Socialtext Schemas
--

-- DROP VIEW xpage;
CREATE OR REPLACE VIEW xpage AS 
    SELECT "Workspace".name AS workspace_name, 
           page.*,
           creator.username AS creator_username,
           editor.username AS editor_username 
        FROM page 
            JOIN "Workspace" ON (page.workspace_id = "Workspace".workspace_id) 
            JOIN "User" editor  ON (page.last_editor_id = editor.user_id) 
            JOIN "User" creator ON (page.creator_id    = creator.user_id);

-- DROP VIEW xpage_tag;
CREATE OR REPLACE VIEW xpage_tag AS 
    SELECT "Workspace".name AS workspace_name, page_tag.*
        FROM page_tag
            JOIN "Workspace" ON (page_tag.workspace_id = "Workspace".workspace_id);

-- DROP VIEW xworkspace;
CREATE OR REPLACE VIEW xworkspace AS 
    SELECT "Workspace".*, "Account".name AS account_name
        FROM "Workspace" 
            JOIN "Account" ON ("Workspace".account_id = "Account".account_id);

-- DROP VIEW xuwr;
CREATE OR REPLACE VIEW xuwr AS 
    SELECT "User".username, 
           "Workspace".name AS workspace_name,
           "Role".name AS role_name
        FROM "UserWorkspaceRole" 
            JOIN "User" ON ("UserWorkspaceRole".user_id = "User".user_id)
            JOIN "Workspace" ON ("UserWorkspaceRole".workspace_id = "Workspace".workspace_id)
            JOIN "Role" ON ("UserWorkspaceRole".role_id = "Role".role_id);

