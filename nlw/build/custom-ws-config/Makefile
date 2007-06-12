#
PREFIX=Test
SST=sudo -u $(SUDOUSER) $(STADMIN)
CREATE=$(SST) create-workspace --name $(WS) --title "$(PREFIX) $(TITLE)" --account Socialtext
DELETE=$(SST) delete-workspace --workspace $(WS) || true 
CONF=$(SST) set-workspace-config --workspace $(WS)
COMMENT_FIELDS=$(SST) set-comment-form-custom-fields --workspace $(WS)
SETUP_ADMIN=$(SST) add-workspace-admin --workspace $(WS) --email $(MEMBER);
SET_PERMISSIONS=$(SST) set-permissions --workspace $(WS) --permissions $(PERMS);\
	$(SST) set-workspace-config --workspace $(WS) email_notify_is_enabled 0
SHOW_ACLS=$(SST) show-acls --workspace $(WS)
EMAIL_OFF=$(SST) set-workspace-config --workspace $(WS) email_notify_is_enabled 0

clean:	
	cd /tmp && sudo rm member-only.*.tar.gz  authenticated-user-only.*.tar.gz  public-read-only.*.tar.gz  fully-public.*.tar.gz || true
	cd /tmp && sudo rm public-comment-only.*.tar.gz  public-authenticate-to-edit.*.tar.gz  intranet.*.tar.gz || true
	cd /tmp && sudo rm test-drkw.*.tar.gz  test-symantec.*.tar.gz  test-lp.*.tar.gz  test-referencemd.*.tar.gz || true


all: STADMIN=../../bin/st-admin
all: SUDOUSER=$(USER)
all: MEMBER=devnull1@socialtext.com
all: skins

test:
	@echo $(USER)
	@echo Done

help:
	@cat Helpfile

staging: STADMIN=/usr/local/bin/st-admin
staging: SUDOUSER=www-data
staging: MEMBER=ken.pier@socialtext.com
staging: spaces

dev: STADMIN=../../bin/st-admin
dev: SUDOUSER=$(USER)
dev: MEMBER=devnull1@socialtext.com
dev: spaces

spaces: publics skins

publics: member-only authenticated-user-only public-read-only fully-public public-comment-only public-authenticate-to-edit intranet

skins: drkw symantec loanperformance referencemd

member-only: WS=member-only
member-only: PERMS=member-only
member-only: TITLE=Member Only
member-only:
	$(DELETE)
	${CREATE}
	${SETUP_ADMIN}
	$(SET_PERMISSIONS)

authenticated-user-only: WS=authenticated-user-only
authenticated-user-only: PERMS=authenticated-user-only
authenticated-user-only: TITLE=Authenticated User Only
authenticated-user-only: 
	$(DELETE)
	${CREATE}
	${SETUP_ADMIN}
	$(SET_PERMISSIONS)

public-read-only: WS=public-read-only
public-read-only: PERMS=public-read-only 
public-read-only: TITLE=Public Read Only
public-read-only: 
	$(DELETE)
	${CREATE}
	${SETUP_ADMIN}
	$(SET_PERMISSIONS)

fully-public: WS=fully-public
fully-public: PERMS=public
fully-public: TITLE=Fully Public
fully-public: 
	$(DELETE)
	${CREATE}
	${SETUP_ADMIN}
	$(SET_PERMISSIONS)

public-comment-only: WS=public-comment-only
public-comment-only: PERMS=public-comment-only
public-comment-only: TITLE=Public Comment Only
public-comment-only: 
	$(DELETE)
	${CREATE}
	${SETUP_ADMIN}
	$(SET_PERMISSIONS)

public-authenticate-to-edit: WS=public-authenticate-to-edit
public-authenticate-to-edit: PERMS=public-authenticate-to-edit
public-authenticate-to-edit: TITLE=Public Authenticate to Edit
public-authenticate-to-edit:
	$(DELETE)
	${CREATE}
	${SETUP_ADMIN}
	$(SET_PERMISSIONS)

intranet: WS=intranet
intranet: PERMS=intranet
intranet: TITLE=Intranet
intranet: 
	$(DELETE)
	${CREATE}
	${SETUP_ADMIN}
	$(SET_PERMISSIONS)


drkw: WS=test-drkw
drkw: TITLE=DrKW
drkw: 
	$(DELETE)
	${CREATE}
	${SETUP_ADMIN}
	$(CONF) skin_name drkw
	$(CONF) header_logo_link_uri 'index.cgi?'
	$(CONF) show_welcome_message_below_logo 1
	$(CONF) show_title_below_logo 0
	$(EMAIL_OFF)

symantec: WS=test-symantec
symantec: TITLE=Symantec
symantec:
	$(DELETE)
	$(CREATE)
	$(SETUP_ADMIN)
	$(CONF) skin_name symantec
	$(CONF) header_logo_link_uri http://www.symantec.com
	$(CONF) show_title_below_logo 0
	$(EMAIL_OFF)

referencemd: WS=test-referencemd
referencemd: TITLE=ReferenceMD
referencemd: 
	$(DELETE)
	$(CREATE)
	$(SETUP_ADMIN)
	$(CONF) skin_name referencemd
	$(CONF) show_title_below_logo 0
	$(CONF) page_title_prefix 'ReferenceMD: '
	$(CONF) comment_form_note_top '&nbsp;<b>Instructions:</b> If referencing existing content, please indicate which section<br> &nbsp;and which paragraph you are referring to in your comments<hr>'
	$(CONF) comment_form_note_bottom '<br>&nbsp;<b>Please identify yourself:</b><p>'
	$(CONF) comment_form_window_height 375
	$(COMMENT_FIELDS) Name Degree Specialty Institution 'City/State' 'Country (if not USA)'
	$(EMAIL_OFF)

loanperformance: WS=test-lp
loanperformance: TITLE=LoanPerformance
loanperformance: 
	$(DELETE)
	$(CREATE)
	$(SETUP_ADMIN)
	$(CONF) skin_name lp
	$(CONF) show_title_below_logo 0
	$(EMAIL_OFF)
