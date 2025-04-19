audit-test-All: 
	sudo forge test --match-path test/AuditTest/DevFundTest.t.sol -vvv && \
	sudo forge test --match-path test/AuditTest/EntityForgingTest.t.sol -vvv && \
	sudo forge test --match-path test/AuditTest/EntityTradingTest.t.sol -vvv --gas-limit 200000000000 && \
	sudo forge test --match-path test/AuditTest/NukeFundTest.t.sol -vvv --gas-limit 200000000000 && \
	sudo forge test --match-path test/AuditTest/TraitForgeNftTest.t.sol -vvv --gas-limit 200000000000