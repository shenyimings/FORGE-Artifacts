pragma solidity ^0.6.12;

import {
    ERC20PausableUpgradeSafe,
    IERC20,
    SafeMath
} from "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Pausable.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import {
    ReentrancyGuardUpgradeSafe
} from "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";

import {AddressArrayUtils} from "./library/AddressArrayUtils.sol";

import {ILimaSwap} from "./interfaces/ILimaSwap.sol";
import {ILimaTokenHelper} from "./interfaces/ILimaTokenHelper.sol";

/**
 * @title LimaToken
 * @author Lima Protocol
 *
 * Standard LimaToken.
 */
contract LimaToken is ERC20PausableUpgradeSafe, ReentrancyGuardUpgradeSafe {
    using AddressArrayUtils for address[];
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Create(address _from, uint256 _amount);
    event Redeem(address _from, uint256 _amount);
    event RebalanceExecute(address _oldToken, address _newToken);

    // address public owner;
    ILimaTokenHelper public limaTokenHelper; //limaTokenStorage
    mapping(address => uint256) internal userLastDeposit;

    /**
     * @dev Initializes contract
     */
    function initialize(
        string memory name,
        string memory symbol,
        address _limaTokenHelper,
        uint256 _underlyingAmount,
        uint256 _limaAmount
    ) public initializer {
        limaTokenHelper = ILimaTokenHelper(_limaTokenHelper);

        __ERC20_init(name, symbol);
        __ERC20Pausable_init();

        if (_underlyingAmount > 0 && _limaAmount > 0) {
            IERC20(limaTokenHelper.currentUnderlyingToken()).safeTransferFrom(
                _msgSender(),
                address(this),
                _underlyingAmount
            );
            _mint(_msgSender(), _limaAmount);
        }
    }

    /* ============ Modifiers ============ */

    modifier onlyUnderlyingToken(address _token) {
        _isOnlyUnderlyingToken(_token);
        _;
    }

    function _isOnlyUnderlyingToken(address _token) internal view {
        // Internal function used to reduce bytecode size
        require(
            limaTokenHelper.isUnderlyingTokens(_token),
            "LM1" //"Only token that are part of Underlying Tokens"
        );
    }

    modifier onlyInvestmentToken(address _investmentToken) {
        // Internal function used to reduce bytecode size
        _isOnlyInvestmentToken(_investmentToken);
        _;
    }

    function _isOnlyInvestmentToken(address _investmentToken) internal view {
        // Internal function used to reduce bytecode size
        require(
            limaTokenHelper.isInvestmentToken(_investmentToken),
            "LM7" //nly token that are approved to invest/payout.
        );
    }

    /**
     * @dev Throws if called by any account other than the limaGovernance.
     */
    modifier onlyLimaGovernanceOrOwner() {
        _isOnlyLimaGovernanceOrOwner();
        _;
    }

    function _isOnlyLimaGovernanceOrOwner() internal view {
        require(
            limaTokenHelper.limaGovernance() == _msgSender() ||
                limaTokenHelper.owner() == _msgSender(),
            "LM2" // "Ownable: caller is not the limaGovernance or owner"
        );
    }

    modifier onlyAmunUsers() {
        _isOnlyAmunUser();
        _;
    }

    function _isOnlyAmunUser() internal view {
        if (limaTokenHelper.isOnlyAmunUserActive()) {
            require(
                limaTokenHelper.isAmunUser(_msgSender()),
                "LM3" //"AmunUsers: msg sender must be part of amunUsers."
            );
        }
    }

    /* ============ View ============ */

    function getUnderlyingTokenBalance() public view returns (uint256 balance) {
        return
            IERC20(limaTokenHelper.currentUnderlyingToken()).balanceOf(
                address(this)
            );
    }

    function getUnderlyingTokenBalanceOf(uint256 _amount)
        public
        view
        returns (uint256 balanceOf)
    {
        return getUnderlyingTokenBalance().mul(_amount).div(totalSupply());
    }

    /* ============ Lima Manager ============ */

    function mint(address account, uint256 amount)
        public
        onlyLimaGovernanceOrOwner
    {
        _mint(account, amount);
    }

    // pausable functions
    function pause() external onlyLimaGovernanceOrOwner {
        _pause();
    }

    function unpause() external onlyLimaGovernanceOrOwner {
        _unpause();
    }

    function _approveLimaSwap(address _token, uint256 _amount) internal {
        if (
            IERC20(_token).allowance(
                address(this),
                address(limaTokenHelper.limaSwap())
            ) < _amount
        ) {
            IERC20(_token).safeApprove(address(limaTokenHelper.limaSwap()), 0);
            IERC20(_token).safeApprove(
                address(limaTokenHelper.limaSwap()),
                limaTokenHelper.MAX_UINT256()
            );
        }
    }

    function _swap(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _minimumReturn
    ) internal returns (uint256 returnAmount) {
        if (address(_from) != address(_to) && _amount > 0) {
            _approveLimaSwap(_from, _amount);

            returnAmount = limaTokenHelper.limaSwap().swap(
                address(this),
                _from,
                _to,
                _amount,
                _minimumReturn
            );
            return returnAmount;
        }
        return _amount;
    }

    function _unwrap(
        address _token,
        uint256 _amount,
        address _recipient
    ) internal {
        if (_amount > 0) {
            _approveLimaSwap(_token, _amount);
            limaTokenHelper.limaSwap().unwrap(_token, _amount, _recipient);
        }
    }

    /**
     * @dev Swaps token to new token
     */
    function swap(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _minimumReturn
    ) public onlyLimaGovernanceOrOwner returns (uint256 returnAmount) {
        return _swap(_from, _to, _amount, _minimumReturn);
    }

    /**
     * @dev Rebalances LimaToken
     * Will do swaps of potential governancetoken, underlying token to token that provides higher return
     */
    function rebalance(address _bestToken, uint256 _minimumReturnGov)
        external
        onlyLimaGovernanceOrOwner()
    {
        require(
            limaTokenHelper.lastRebalance() +
                limaTokenHelper.rebalanceInterval() <
                now,
            "LM5" //"Rebalance only every 24 hours"
        );

        limaTokenHelper.setLastRebalance(now);

        //send fee to fee wallet
        _unwrap(
            limaTokenHelper.currentUnderlyingToken(),
            limaTokenHelper.getPerformanceFee(),
            limaTokenHelper.feeWallet()
        );

        address govToken = limaTokenHelper.getGovernanceToken();
        //swap gov
        _swap(
            govToken,
            _bestToken,
            IERC20(govToken).balanceOf(address(this)),
            _minimumReturnGov
        );

        //swap underlying
        _swap(
            limaTokenHelper.currentUnderlyingToken(),
            _bestToken,
            getUnderlyingTokenBalance(),
            limaTokenHelper
                .limaSwap()
                .getUnderlyingAmount(
                limaTokenHelper.currentUnderlyingToken(),
                getUnderlyingTokenBalance()
            )
                .mul(980)
                .div(1000) //cose it is 1 to 1 ?
        );
        emit RebalanceExecute(
            limaTokenHelper.currentUnderlyingToken(),
            _bestToken
        );
        limaTokenHelper.setCurrentUnderlyingToken(_bestToken);
        limaTokenHelper.setLastUnderlyingBalancePer1000(
            getUnderlyingTokenBalanceOf(1000 ether)
        );
    }

    /**
     * @dev Redeem the value of LimaToken in _payoutToken.
     * @param _payoutToken The address of token to payout with.
     * @param _amount The amount to redeem.
     * @param _recipient The user address to redeem from/to.
     * @param _minimumReturn The minimum amount to return or else revert.
     */
    function forceRedeem(
        address _payoutToken,
        uint256 _amount,
        address _recipient,
        uint256 _minimumReturn
    ) external onlyLimaGovernanceOrOwner returns (bool) {
        return
            _redeem(
                _recipient,
                _payoutToken,
                _amount,
                _recipient,
                _minimumReturn
            );
    }

    /* ============ User ============ */

    /**
     * @dev Creates new token for holder by converting _investmentToken value to LimaToken
     * Note: User need to approve _amount on _investmentToken to this contract
     * @param _investmentToken The address of token to invest with.
     * @param _amount The amount of investment token to create lima token from.
     * @param _recipient The address to transfer the lima token to.
     * @param _minimumReturn The minimum amount to return or else revert.
     */
    function create(
        address _investmentToken,
        uint256 _amount,
        address _recipient,
        uint256 _minimumReturn
    )
        external
        nonReentrant
        onlyInvestmentToken(_investmentToken)
        onlyAmunUsers
        returns (bool)
    {
        require(
            block.number + 2 > userLastDeposit[_msgSender()],
            "cannot withdraw within the same block"
        );
        userLastDeposit[tx.origin] = block.number;
        uint256 balance = getUnderlyingTokenBalance();

        IERC20(_investmentToken).safeTransferFrom(
            _msgSender(),
            address(this),
            _amount
        );
        //get fee
        uint256 fee = limaTokenHelper.getFee(
            _amount,
            limaTokenHelper.mintFee()
        );
        if (fee > 0) {
            IERC20(_investmentToken).safeTransfer(
                limaTokenHelper.feeWallet(),
                fee
            );
            _amount = _amount - fee;
        }
        _amount = _swap(
            _investmentToken,
            limaTokenHelper.currentUnderlyingToken(),
            _amount,
            _minimumReturn
        );
        _amount = totalSupply().mul(_amount).div(balance);
        require(_amount > 0, "zero");

        _mint(_recipient, _amount);

        emit Create(_msgSender(), _amount);
        return true;
    }

    function _redeem(
        address _investor,
        address _payoutToken,
        uint256 _amount,
        address _recipient,
        uint256 _minimumReturn
    ) internal nonReentrant onlyInvestmentToken(_payoutToken) returns (bool) {
        require(
            block.number + 2 > userLastDeposit[_msgSender()],
            "cannot withdraw within the same block"
        );
        userLastDeposit[tx.origin] = block.number;
        uint256 underlyingAmount = getUnderlyingTokenBalanceOf(_amount);
        _burn(_investor, _amount);

        uint256 fee = limaTokenHelper.getFee(
            underlyingAmount,
            limaTokenHelper.burnFee()
        );
        if (fee > 0) {
            _unwrap(
                limaTokenHelper.currentUnderlyingToken(),
                fee,
                limaTokenHelper.feeWallet()
            );
            underlyingAmount = underlyingAmount - fee;
        }
        emit Redeem(_msgSender(), _amount);

        _amount = _swap(
            limaTokenHelper.currentUnderlyingToken(),
            _payoutToken,
            underlyingAmount,
            _minimumReturn
        );
        require(_amount > 0, "zero");
        IERC20(_payoutToken).safeTransfer(_recipient, _amount);

        return true;
    }

    /**
     * @dev Redeem the value of LimaToken in _payoutToken.
     * @param _payoutToken The address of token to payout with.
     * @param _amount The amount of lima token to redeem.
     * @param _recipient The address to transfer the payout token to.
     * @param _minimumReturn The minimum amount to return or else revert.
     */
    function redeem(
        address _payoutToken,
        uint256 _amount,
        address _recipient,
        uint256 _minimumReturn
    ) external returns (bool) {
        return
            _redeem(
                _msgSender(),
                _payoutToken,
                _amount,
                _recipient,
                _minimumReturn
            );
    }
}
