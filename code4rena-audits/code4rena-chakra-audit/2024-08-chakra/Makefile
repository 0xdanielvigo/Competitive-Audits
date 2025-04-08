audit-test-All: 
	sudo forge test --via-ir -vvv

audit-test-GeneralTest: 	
	sudo forge test --match-path test/AuditTest/GeneralTest/GeneralTestBurnUnlockNotUsingChakraToken.t.sol -vvv --via-ir && \
	sudo forge test --match-path test/AuditTest/GeneralTest/GeneralTestLockMint.t.sol -vvv --via-ir && \
	sudo forge test --match-path test/AuditTest/GeneralTest/GeneralTestLockUnlock.t.sol -vvv --via-ir && \
	sudo forge test --match-path test/AuditTest/GeneralTest/GeneralTestLockUnlockNotUsingChakraToken.t.sol -vvv --via-ir && \
	sudo forge test --match-path test/AuditTest/GeneralTest/GeneralTestMintBurn.t.sol -vvv --via-ir

audit-test-HandlerTest: 
	sudo forge test --match-path test/AuditTest/HandlerTest/ChakraSettlementHandlerTest.t.sol -vvv

audit-test-SettlementTest: 
	sudo forge test --match-path test/AuditTest/SettlementTest/ChakraSettlementTest.t.sol -vvv




