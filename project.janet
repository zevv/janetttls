(declare-project :name "openssl")

(declare-native
  :name "openssl"
  :source @["openssl.c"]
  :lflags @["-lcrypto" "-lssl"]
  :nostatic true
  )
