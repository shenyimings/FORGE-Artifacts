import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/interfaces/IERC20.sol";
import "./utils/utils.sol";
import "../contracts/GRouter.sol";
import "../contracts/GVault.sol";
import "../contracts/GTranche.sol";
import "../contracts/oracles/CurveOracle.sol";
import "../contracts/pnl/PnLFixedRate.sol";
import "../contracts/strategy/stop-loss/StopLossLogic.sol";
import {GStrategyGuard} from "../contracts/strategy/keeper/GStrategyGuard.sol";
import "../contracts/strategy/keeper/GStrategyResolver.sol";
import "../contracts/mocks/MockStrategy.sol";
import "../contracts/strategy/ConvexStrategy.sol";
import "../contracts/solmate/src/utils/SafeTransferLib.sol";
import "../contracts/solmate/src/utils/CREATE3.sol";
import {TokenCalculations} from "../contracts/common/TokenCalculations.sol";

interface IConvexRewards {
    function rewardRate() external view returns (uint256);

    function periodFinish() external view returns (uint256);
}

// Base fixture
contract BaseSetup is Test {
    using stdStorage for StdStorage;
    using SafeTransferLib for ERC20;
    bytes32 public DAI_DOMAIN_SEPARATOR =
        0xdbb8cf42e1ecb028be3f3dbc922e1d878b963f411dc388ced501601c60f7c6f7;
    bytes32 public DAI_TYPEHASH =
        0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;

    bytes32 public USDC_DOMAIN_SEPARATOR =
        0x06c37168a7db5138defc7866392bb87a741f9b3d104deb5094588ce041cae335;
    bytes32 public USDC_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    address public constant THREE_POOL =
        address(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    ERC20 public constant THREE_POOL_TOKEN =
        ERC20(address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490));
    ERC20 public constant DAI =
        ERC20(address(0x6B175474E89094C44Da98b954EedeAC495271d0F));
    ERC20 public constant USDC =
        ERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
    ERC20 public constant USDT =
        ERC20(address(0xdAC17F958D2ee523a2206206994597C13D831ec7));
    ERC20 public constant CURVE_TOKEN =
        ERC20(address(0xD533a949740bb3306d119CC777fa900bA034cd52));
    address constant COFFEE_ADDRESS =
        address(0xc0ffEE4a95F15ff9973A17E563a8A8701D719890);
    address constant BASED_ADDRESS =
        address(0xBA5EDF9dAd66D9D81341eEf8131160c439dbA91B);
    address constant ZERO = address(0x0000000000000000000000000000000000000000);
    uint256 constant MAX_UINT = type(uint256).max;
    uint256 constant MIN_DELAY = 259200;

    address[3] public CHAINLINK_AGG_ADDRESSES;
    address[2] public TRANCHE_TOKENS;
    address[] public YIELD_VAULTS;

    GTranche gTranche;
    GVault gVault;
    MockStrategy strategy;
    CurveOracle curveOracle;
    GRouter gRouter;
    PnLFixedRate pnl;

    Utils internal utils;

    address payable[] internal users;
    address internal alice;
    address internal bob;
    address internal joe;
    address internal torsten;

    function setUp() public virtual {
        utils = new Utils();
        users = utils.createUsers(4);

        alice = users[0];
        vm.label(alice, "Alice");
        bob = users[1];
        vm.label(bob, "Bob");
        joe = users[2];
        vm.label(joe, "Joe");
        torsten = users[3];
        vm.label(torsten, "Torsten");

        CHAINLINK_AGG_ADDRESSES[0] = address(
            0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9
        );
        CHAINLINK_AGG_ADDRESSES[1] = address(
            0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6
        );
        CHAINLINK_AGG_ADDRESSES[2] = address(
            0x3E7d1eAB13ad0104d2750B8863b489D65364e32D
        );
        vm.deal(BASED_ADDRESS, 100000e18);
        bytes32 salt = bytes32(uint256(block.number));
        address tokenLogic = arbitraryCreate(
            salt,
            type(TokenCalculations).creationCode,
            1e18
        );
        vm.startPrank(BASED_ADDRESS);
        curveOracle = new CurveOracle();
        gVault = new GVault(THREE_POOL_TOKEN);
        strategy = new MockStrategy(address(gVault));
        gVault.addStrategy(address(strategy), 10000);
        YIELD_VAULTS.push(address(gVault));

        gTranche = new GTranche(
            YIELD_VAULTS,
            IOracle(curveOracle),
            ITokenLogic(tokenLogic)
        );

        pnl = new PnLFixedRate(address(gTranche));

        gTranche.setPnL(pnl);
        gRouter = new GRouter(
            gTranche,
            gVault,
            ICurve3Pool(THREE_POOL),
            ERC20(THREE_POOL_TOKEN),
            [address(DAI), address(USDC), address(USDT)]
        );
        vm.stopPrank();
    }

    function arbitraryCreate(
        bytes32 salt,
        bytes memory creationCode,
        uint256 ethValue
    ) public returns (address) {
        return CREATE3.deploy(salt, creationCode, ethValue);
    }

    function findStorage(
        address _user,
        bytes4 _selector,
        address _contract
    ) public returns (uint256) {
        uint256 slot = stdstore
            .target(_contract)
            .sig(_selector)
            .with_key(_user)
            .find();
        bytes32 data = vm.load(_contract, bytes32(slot));
        return uint256(data);
    }

    function setStorage(
        address _user,
        bytes4 _selector,
        address _contract,
        uint256 value
    ) public {
        uint256 slot = stdstore
            .target(_contract)
            .sig(_selector)
            .with_key(_user)
            .find();
        vm.store(_contract, bytes32(slot), bytes32(value));
    }

    function prepUser(address _user) internal {
        vm.startPrank(_user);
        DAI.approve(address(gRouter), MAX_UINT);
        gTranche.setApprovalForAll(address(gRouter), true);
        setStorage(
            _user,
            DAI.balanceOf.selector,
            address(DAI),
            type(uint256).max
        );
        vm.stopPrank();
    }

    function prepUserCrv(address _user) internal {
        vm.startPrank(_user);
        DAI.approve(address(THREE_POOL), MAX_UINT);
        THREE_POOL_TOKEN.approve(address(gVault), MAX_UINT);
        ERC20(address(gVault)).approve(address(gTranche), MAX_UINT);
        setStorage(
            _user,
            DAI.balanceOf.selector,
            address(DAI),
            type(uint256).max
        );
        vm.stopPrank();
    }

    function delta(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function genThreeCrv(uint256 amount, address _user)
        public
        returns (uint256)
    {
        vm.startPrank(_user);
        DAI.approve(THREE_POOL, amount);
        USDC.approve(THREE_POOL, amount);
        if (ERC20(address(USDT)).allowance(_user, THREE_POOL) > 0) {
            ERC20(address(USDT)).safeApprove(THREE_POOL, 0);
        }
        ERC20(address(USDT)).safeApprove(THREE_POOL, amount);
        uint256 dai = amount;
        uint256 usdt = amount / 10**12;
        uint256 usdc = amount / 10**12;
        setStorage(
            _user,
            DAI.balanceOf.selector,
            address(DAI),
            type(uint256).max
        );
        setStorage(
            _user,
            USDC.balanceOf.selector,
            address(USDC),
            type(uint256).max
        );
        setStorage(
            _user,
            USDT.balanceOf.selector,
            address(USDT),
            type(uint256).max
        );

        ICurve3Pool(THREE_POOL).add_liquidity([dai, usdc, usdt], 0);

        vm.stopPrank();

        return THREE_POOL_TOKEN.balanceOf(_user);
    }

    function genStable(
        uint256 amount,
        address token,
        address _user
    ) public {
        setStorage(
            _user,
            IERC20(token).balanceOf.selector,
            token,
            type(uint256).max
        );
    }

    function manipulatePool(
        bool profit,
        uint256 change,
        address pool,
        address token
    ) public {
        uint256 tokenAmount = IERC20(token).balanceOf(pool);
        tokenAmount = ((tokenAmount * 10000) / (10000 - change));
        _manipulatePool(profit, pool, token, tokenAmount);
    }

    // Manipulate pool with smaller token amount
    function manipulatePoolSmallerTokenAmount(
        bool profit,
        uint256 change,
        address pool,
        address token
    ) public returns (uint256, uint256) {
        uint256 tokenAmount = IERC20(token).balanceOf(pool);
        tokenAmount = ((tokenAmount * change) / (10000));
        uint256 amount = _manipulatePool(profit, pool, token, tokenAmount);
        return (amount, tokenAmount);
    }

    function reverseManipulation(
        bool profit,
        uint256 tokenAmount,
        address pool,
        address token
    ) public returns (uint256, uint256) {
        uint256 amount;
        vm.startPrank(BASED_ADDRESS);
        IERC20(token).approve(pool, type(uint256).max);
        if (profit) {
            amount = ICurveMeta(pool).exchange(1, 0, tokenAmount, 0);
        } else {
            amount = ICurveMeta(pool).exchange(0, 1, tokenAmount, 0);
        }
        vm.stopPrank();
        return (amount, tokenAmount);
    }

    function _manipulatePool(
        bool profit,
        address pool,
        address token,
        uint256 tokenAmount
    ) internal returns (uint256) {
        genStable(tokenAmount, token, BASED_ADDRESS);

        vm.startPrank(BASED_ADDRESS);
        IERC20(token).approve(pool, type(uint256).max);
        uint256 amount;
        if (profit) {
            amount = ICurveMeta(pool).exchange(1, 0, tokenAmount, 0);
        } else {
            amount = ICurveMeta(pool).exchange(0, 1, tokenAmount, 0);
        }
        vm.stopPrank();
        return amount;
    }

    function depositIntoVault(address _user, uint256 _amount)
        public
        returns (uint256 shares)
    {
        uint256 balance = genThreeCrv(_amount, _user);
        vm.startPrank(_user);
        THREE_POOL_TOKEN.approve(address(gVault), balance);
        shares = gVault.deposit(balance, _user);
        vm.stopPrank();
    }

    function prepareRewards(address _convexPool) public {
        uint256 slot = stdstore
            .target(_convexPool)
            .sig(IConvexRewards(_convexPool).rewardRate.selector)
            .find();
        vm.store(
            _convexPool,
            bytes32(slot),
            bytes32(50 * IConvexRewards(_convexPool).rewardRate())
        );
        vm.warp(IConvexRewards(_convexPool).periodFinish() - 100);
    }

    /// @notice utils function to sign permit and return k, v and r
    function signPermitDAI(
        address owner,
        address spender,
        uint256 nonce,
        uint256 deadline,
        uint256 pkey
    )
        public
        returns (
            uint8 v,
            bytes32 r,
            bytes32 s
        )
    {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DAI_DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        DAI_TYPEHASH,
                        owner,
                        spender,
                        nonce,
                        deadline,
                        true // Allowed
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkey, hash);
        assertEq(owner, ecrecover(hash, v, r, s));
        return (v, r, s);
    }

    /// @notice utils function to sign permit and return k, v and r
    function signPermitUSDC(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline,
        uint256 pkey
    )
        public
        returns (
            uint8 v,
            bytes32 r,
            bytes32 s
        )
    {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                USDC_DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        USDC_TYPEHASH,
                        owner,
                        spender,
                        value,
                        nonce,
                        deadline
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkey, hash);
        assertEq(owner, ecrecover(hash, v, r, s));
        return (v, r, s);
    }

    function runDeposit(
        address payable[] memory _users,
        uint256 deposit,
        uint256 i,
        uint256 k
    ) public {
        bool _break;
        for (uint256 j; j < i; j++) {
            address user = _users[j];
            prepUserCrv(user);
            vm.startPrank(user);
            _break = false;
            for (uint256 l; l < k; l++) {
                if (deposit > DAI.balanceOf(user)) {
                    ICurve3Pool(THREE_POOL).add_liquidity(
                        [DAI.balanceOf(user), 0, 0],
                        0
                    );
                } else {
                    ICurve3Pool(THREE_POOL).add_liquidity([deposit, 0, 0], 0);
                }
                uint256 balance = THREE_POOL_TOKEN.balanceOf(address(user));
                uint256 shares = gVault.deposit(balance, address(user));

                gTranche.deposit(shares / 2, 0, false, address(user));
                gTranche.deposit(shares / 2, 0, true, address(user));
                if (_break) break;
            }
            vm.stopPrank();
        }
    }

    function _withdraw(
        bool tranche,
        uint256 amount,
        address user
    ) public returns (uint256 withdrawAmount) {
        (, withdrawAmount) = gTranche.withdraw(amount, 0, tranche, user);
    }

    function userWithdrawCheck(
        address user,
        uint256 userSeniorAssets,
        uint256 userJuniorAssets,
        uint256 k
    )
        public
        returns (uint256 seniorAmountWithdrawn, uint256 juniorAmountWithdrawn)
    {
        uint256 SeniorTrancheAssets;
        uint256 JuniorTrancheAssets;

        for (uint256 l; l < k; l++) {
            JuniorTrancheAssets = gTranche.trancheBalances(0);
            vm.startPrank(user);
            if (l + 1 == k) {
                seniorAmountWithdrawn += _withdraw(
                    true,
                    gTranche.balanceOfWithFactor(user, 1),
                    address(user)
                );
            } else {
                seniorAmountWithdrawn += _withdraw(
                    true,
                    userSeniorAssets / k,
                    address(user)
                );
            }
            assertApproxEqAbs(
                gTranche.trancheBalances(0),
                JuniorTrancheAssets,
                1E6
            );

            SeniorTrancheAssets = gTranche.trancheBalances(1);
            if (l + 1 == k) {
                juniorAmountWithdrawn += _withdraw(
                    false,
                    gTranche.balanceOfWithFactor(user, 0),
                    address(user)
                );
            } else {
                juniorAmountWithdrawn += _withdraw(
                    false,
                    userJuniorAssets / k,
                    address(user)
                );
            }
            vm.stopPrank();
            assertApproxEqAbs(
                gTranche.trancheBalances(1),
                SeniorTrancheAssets,
                1E6
            );
        }
    }

    function runWithdrawal(address user, uint256 k)
        public
        returns (uint256 withdrawnSenior, uint256 withdrawnJunior)
    {
        uint256 userSeniorAssets = gTranche.balanceOfWithFactor(user, 1);
        uint256 userJuniorAssets = gTranche.balanceOfWithFactor(user, 0);

        uint256 initialSeniorTrancheAssets = gTranche.trancheBalances(1);
        uint256 initialJuniorTrancheAssets = gTranche.trancheBalances(0);

        (withdrawnSenior, withdrawnJunior) = userWithdrawCheck(
            user,
            userSeniorAssets,
            userJuniorAssets,
            k
        );

        assertApproxEqAbs(
            gTranche.trancheBalances(0),
            delta(initialJuniorTrancheAssets, withdrawnJunior),
            1E6
        );
        assertApproxEqAbs(
            gTranche.trancheBalances(1),
            delta(initialSeniorTrancheAssets, withdrawnSenior),
            1E6
        );
    }
}
