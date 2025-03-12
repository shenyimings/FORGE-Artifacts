import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/interfaces/IERC20.sol";
import "./utils/utils.sol";
import "../contracts/interfaces/IOracle.sol";
import "../contracts/GRouter.sol";
import "../contracts/GVault.sol";
import "../contracts/GTranche.sol";
import "../contracts/pnl/PnLFixedRate.sol";
import "../contracts/mocks/MockERC20.sol";
import "../contracts/mocks/Mock3CRV.sol";
import "../contracts/mocks/MockDAI.sol";
import "../contracts/mocks/MockUSDC.sol";
import "../contracts/mocks/MockUSDT.sol";
import "../contracts/mocks/MockUSDT.sol";
import "../contracts/mocks/MockStrategy.sol";
import "../contracts/mocks/MockCurveOracle.sol";
import "../contracts/mocks/MockThreePoolCurve.sol";
import "../contracts/solmate/src/utils/SafeTransferLib.sol";
import {TokenCalculations} from "../contracts/common/TokenCalculations.sol";
import "../contracts/solmate/src/utils/CREATE3.sol";

contract BaseUnitFixture is Test {
    using stdStorage for StdStorage;
    using SafeTransferLib for ERC20;

    address[] public YIELD_VAULTS;

    GTranche public gTranche;
    GVault public gVault;
    MockStrategy public strategy;
    IOracle public curveOracle;
    GRouter public gRouter;
    PnLFixedRate public pnl;
    MockERC20 public threeCurveToken;
    Utils internal utils;
    MockThreePoolCurve public threePoolCurve;
    MockERC20 public dai;
    MockERC20 public usdt;
    MockERC20 public usdc;

    address payable[] internal users;
    address internal alice;
    address internal bob;
    address internal joe;
    address internal torsten;

    function arbitraryCreate(
        bytes32 salt,
        bytes memory creationCode,
        uint256 ethValue
    ) public returns (address) {
        return CREATE3.deploy(salt, creationCode, ethValue);
    }

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

        bytes32 salt = bytes32(uint256(block.number));
        address tokenLogic = arbitraryCreate(
            salt,
            type(TokenCalculations).creationCode,
            1e18
        );
        threePoolCurve = new MockThreePoolCurve();
        threeCurveToken = new Mock3CRV();
        threePoolCurve.setThreeCrv(address(threeCurveToken));
        dai = new MockDAI();
        usdc = new MockUSDC();
        usdt = new MockUSDT();
        curveOracle = new MockCurveOracle();
        gVault = new GVault(threeCurveToken);
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
            MockThreePoolCurve(address(threePoolCurve)),
            ERC20(threeCurveToken),
            [address(dai), address(usdc), address(usdt)]
        );
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

    /// @dev simulate a deposit into the vault and obtaining shares
    function depositIntoVault(address _user, uint256 _amount)
        internal
        returns (uint256 shares)
    {
        uint256 balance = genThreeCrv(_user, _amount);
        vm.startPrank(_user);
        threeCurveToken.approve(address(gVault), balance);
        shares = gVault.deposit(balance, _user);
        vm.stopPrank();
    }

    function genThreeCrv(address _user, uint256 _amount)
        public
        returns (uint256)
    {
        vm.startPrank(_user);
        dai.approve(address(threePoolCurve), type(uint256).max);
        usdc.approve(address(threePoolCurve), type(uint256).max);
        if (
            ERC20(address(usdt)).allowance(_user, address(threePoolCurve)) > 0
        ) {
            ERC20(address(usdt)).safeApprove(address(threePoolCurve), 0);
        }
        ERC20(address(usdt)).safeApprove(
            address(threePoolCurve),
            type(uint256).max
        );
        dai.faucet(type(uint256).max);
        usdc.faucet(type(uint256).max);
        usdt.faucet(type(uint256).max);
        uint256[3] memory amounts = [_amount, _amount / 1e12, _amount / 1e12];
        threePoolCurve.add_liquidity(amounts, 0);

        vm.stopPrank();
        return threeCurveToken.balanceOf(_user);
    }
}
