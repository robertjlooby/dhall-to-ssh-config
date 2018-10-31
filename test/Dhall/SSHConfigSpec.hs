{-# LANGUAGE OverloadedStrings #-}

module Dhall.SSHConfigSpec
  ( spec
  ) where

import qualified Data.Text.IO
import qualified Dhall
import Dhall.SSHConfig
import Test.Hspec
  ( Expectation
  , Spec
  , describe
  , expectationFailure
  , it
  , shouldBe
  )

expectFailure :: Dhall.Text -> Expectation
expectFailure input = do
  expr <- Dhall.inputExpr input
  case dhallToSSHConfig expr of
    Right t -> expectationFailure ("Expected failure. Got: " <> show t)
    Left _ -> return ()

shouldConvertTo :: Dhall.Text -> Dhall.Text -> Expectation
shouldConvertTo input output = do
  expr <- Dhall.inputExpr input
  dhallToSSHConfig expr `shouldBe` Right output

spec :: Spec
spec = do
  describe "dhallToSSHConfig" $ do
    describe "empty configs" $ do
      it "for an empty config" $ "[] : List {host : Text}" `shouldConvertTo` ""
      it "for the wrong top level element" $ expectFailure "{=}"
    describe "the host config" $ do
      it "for a record without a host config" $
        expectFailure "[{hostName = Some \"1.2.3.4\"}]"
      it "for a host value other than text" $ expectFailure "[{host = 2}]"
      it "for multiple host value other than text" $
        expectFailure "[{host = [1, 2]}]"
      it "for a single host config" $
        "[{host = \"test\"}]" `shouldConvertTo` "Host test\n"
      it "for multiple host configs" $
        "[{host = \"test\"}, {host = \"other\"}]" `shouldConvertTo`
        "Host test\n\nHost other\n"
      it "for configs with multiple hosts" $
        "[{host = [\"test\", \"test2\"]}, {host = [\"other\", \"other2\"]}]" `shouldConvertTo`
        "Host test test2\n\nHost other other2\n"
    describe "the addKeysToAgent config" $ do
      it "for an addKeysToAgent value other than optional text" $
        expectFailure "[{host = \"test\", addKeysToAgent = 1234}]"
      it "for a single addKeysToAgent config of 'ask'" $
        "[{host = \"test\", addKeysToAgent = Some \"ask\"}]" `shouldConvertTo`
        "Host test\n     AddKeysToAgent ask\n"
      it "for a single addKeysToAgent config of 'confirm'" $
        "[{host = \"test\", addKeysToAgent = Some \"confirm\"}]" `shouldConvertTo`
        "Host test\n     AddKeysToAgent confirm\n"
      it "for a single addKeysToAgent config of 'no'" $
        "[{host = \"test\", addKeysToAgent = Some \"no\"}]" `shouldConvertTo`
        "Host test\n     AddKeysToAgent no\n"
      it "for a single addKeysToAgent config of 'yes'" $
        "[{host = \"test\", addKeysToAgent = Some \"yes\"}]" `shouldConvertTo`
        "Host test\n     AddKeysToAgent yes\n"
      it "for an addKeysToAgent value other than optional enum value" $
        expectFailure "[{host = \"test\", addKeysToAgent = Some \"other\"}]"
    describe "the hostName config" $ do
      it "for a hostName value other than optional text" $
        expectFailure "[{host = \"test\", hostName = 1234}]"
      it "for a single hostName config" $
        "[{host = \"test\", hostName = Some \"1.2.3.4\"}]" `shouldConvertTo`
        "Host test\n     HostName 1.2.3.4\n"
    describe "the identityFile config" $ do
      it "for an identityFile value other than optional text" $
        expectFailure "[{host = \"test\", identityFile = 1234}]"
      it "for a single identityFile config" $
        "[{host = \"test\", identityFile = Some \"~/.ssh/id_rsa\"}]" `shouldConvertTo`
        "Host test\n     IdentityFile ~/.ssh/id_rsa\n"
    describe "the port config" $ do
      it "for a port value other than optional natural" $
        expectFailure "[{host = \"test\", port = -1234}]"
      it "for a single port config" $
        "[{host = \"test\", port = Some 123}]" `shouldConvertTo`
        "Host test\n     Port 123\n"
    describe "the useKeychain config" $ do
      it "for an useKeychain value other than optional text" $
        expectFailure "[{host = \"test\", useKeychain = 1234}]"
      it "for a single UseKeychain config of 'no'" $
        "[{host = \"test\", useKeychain = Some \"no\"}]" `shouldConvertTo`
        "Host test\n     UseKeychain no\n"
      it "for a single useKeychain config of 'yes'" $
        "[{host = \"test\", useKeychain = Some \"yes\"}]" `shouldConvertTo`
        "Host test\n     UseKeychain yes\n"
      it "for an useKeychain value other than optional enum value" $
        expectFailure "[{host = \"test\", useKeychain = Some \"other\"}]"
    describe "the user config" $ do
      it "for a user value other than optional text" $
        expectFailure "[{host = \"test\", user = 1234}]"
      it "for a single user config" $
        "[{host = \"test\", user = Some \"admin\"}]" `shouldConvertTo`
        "Host test\n     User admin\n"
    it "handles a full example config" $ do
      dhall <-
        Data.Text.IO.readFile "./test/Dhall/fullExample.dhall" >>=
        Dhall.inputExpr
      sshConfig <- Data.Text.IO.readFile "./test/Dhall/fullExample"
      dhallToSSHConfig dhall `shouldBe` Right sshConfig
    it "handles a full example config with multiple hosts per config" $ do
      dhall <-
        Data.Text.IO.readFile "./test/Dhall/fullExampleMultipleHosts.dhall" >>=
        Dhall.inputExpr
      sshConfig <- Data.Text.IO.readFile "./test/Dhall/fullExampleMultipleHosts"
      dhallToSSHConfig dhall `shouldBe` Right sshConfig
  it "the empty config is valid Dhall and doesn't add any configuration" $
    "[./resources/EmptySSHConfig.dhall // {host = \"test\"}]" `shouldConvertTo`
    "Host test\n"
