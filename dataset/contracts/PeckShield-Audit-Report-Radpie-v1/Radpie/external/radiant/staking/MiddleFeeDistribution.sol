// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../../../interfaces/radiant/IMiddleFeeDistribution.sol";
import "../../../interfaces/radiant/IMultiFeeDistribution.sol";
import "../../../interfaces/radiant/IMintableToken.sol";
import "../../../interfaces/radiant/IAaveOracle.sol";
import "../../../interfaces/radiant/IAToken.sol";
import "../../../interfaces/chainlink/AggregatorV3Interface.sol";
import "hardhat/console.sol";

/// @title Fee distributor inside
/// @author Radiant
/// @dev All function calls are currently implemented without side effects
contract MiddleFeeDistribution is IMiddleFeeDistribution, Initializable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice RDNT token
    IMintableToken public rdntToken;

    /// @notice Fee distributor contract for earnings and RDNT lockings
    IMultiFeeDistribution public multiFeeDistribution;

    /// @notice Reward ratio for operation expenses
    uint256 public override operationExpenseRatio = 1500;

    uint256 public constant RATIO_DIVISOR = 10000;

    uint8 public constant DECIMALS = 18;

    mapping(address => bool) public override isRewardToken;

    /// @notice Operation Expense account
    address public override operationExpenses;

    /// @notice Admin address
    address public admin;

    // AAVE Oracle address
    address internal _aaveOracle;

    /********************** Events ***********************/

    /// @notice Emitted when ERC20 token is recovered
    event Recovered(address token, uint256 amount);

    /// @notice Emitted when reward token is forwarded
    event ForwardReward(address token, uint256 amount);

    /// @notice Emitted when OpEx info is updated
    event SetOperationExpenses(address opEx, uint256 ratio);

    /// @notice Emitted when operation expenses is set
    event OperationExpensesUpdated(address _operationExpenses, uint256 _operationExpenseRatio);

    event NewTransferAdded(address indexed asset, uint256 lpUsdValue);

    /**
     * @dev Throws if called by any account other than the admin or owner.
     */
    // modifier onlyAdminOrOwner() {
    //     require(
    //         admin == _msgSender() || owner() == _msgSender(),
    //         "caller is not the admin or owner"
    //     );
    //     _;
    // }

    constructor(
        address _rdntToken,
        address aaveOracle,
        IMultiFeeDistribution _multiFeeDistribution
    ) {
        rdntToken = IMintableToken(_rdntToken);
        _aaveOracle = aaveOracle;
        multiFeeDistribution = _multiFeeDistribution;

        admin = msg.sender;
    }

    /**
     * @notice Set operation expenses account
     */
    function setOperationExpenses(
        address _operationExpenses,
        uint256 _operationExpenseRatio
    ) external {
        require(_operationExpenseRatio <= RATIO_DIVISOR, "Invalid ratio");
        require(_operationExpenses != address(0), "operationExpenses is 0 address");
        operationExpenses = _operationExpenses;
        operationExpenseRatio = _operationExpenseRatio;
        emit OperationExpensesUpdated(_operationExpenses, _operationExpenseRatio);
    }

    function setAdmin(address _configurator) external {
        require(_configurator != address(0), "configurator is 0 address");
        admin = _configurator;
    }

    /**
     * @notice Add a new reward token to be distributed to stakers
     */
    function addReward(address _rewardsToken) external override {
        multiFeeDistribution.addReward(_rewardsToken);
        isRewardToken[_rewardsToken] = true;
    }

    /**
     * @notice Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
     */
    function forwardReward(address[] memory _rewardTokens) external override {
        require(msg.sender == address(multiFeeDistribution), "!mfd");

        for (uint256 i = 0; i < _rewardTokens.length; i += 1) {
            uint256 total = IERC20(_rewardTokens[i]).balanceOf(address(this));
            
            if (operationExpenses == address(0) && operationExpenseRatio != 0) {
                uint256 opExAmount = total.mul(operationExpenseRatio).div(RATIO_DIVISOR);
                // if (opExAmount != 0) {
                //     IERC20(_rewardTokens[i]).safeTransfer(operationExpenses, opExAmount);
                // }
                total = total.sub(opExAmount);
            }
            total = IERC20(_rewardTokens[i]).balanceOf(address(this));
            IERC20(_rewardTokens[i]).safeTransfer(address(multiFeeDistribution), total);

            //emitNewTransferAdded(_rewardTokens[i], total);
        }
    }

    function getRdntTokenAddress() external view override returns (address) {
        return address(rdntToken);
    }

    function getMultiFeeDistributionAddress() external view override returns (address) {
        return address(multiFeeDistribution);
    }

    /**
     * @notice Returns lock information of a user.
     * @dev It currently returns just MFD infos.
     */
    function lockedBalances(
        address user
    )
        external
        view
        override
        returns (
            uint256 total,
            uint256 unlockable,
            uint256 locked,
            uint256 lockedWithMultiplier,
            LockedBalance[] memory lockData
        )
    {
        return multiFeeDistribution.lockedBalances(user);
    }

    /**
     * @notice Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
     */
    // function recoverERC20(address tokenAddress, uint256 tokenAmount) external {
    //     IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
    //     emit Recovered(tokenAddress, tokenAmount);
    // }
}
