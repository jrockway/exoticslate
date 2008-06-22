id: oak-testing
backend: ActiveDirectory
host: oak.socialtext.net
port: 389
base: cn=users,dc=ad-social,dc=socialt,dc=net
bind_user: testme
bind_password: Ko013344
attr_map:
  user_id: distinguishedName
  username: sAMAccountName
  first_name: givenName
  last_name: sn
  email_address: mail
