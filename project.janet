(declare-project :name "sslapi")

(declare-native
  :name "sslapi"
  :source @["sslapi.c"]
  :lflags @["-lcrypto" "-lssl"]
  :nostatic true
  )
