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
    OwnableUpgradeSafe
} from "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import {AddressArrayUtils} from "./library/AddressArrayUtils.sol";
import {OwnableLimaGovernance} from "./limaTokenModules/OwnableLimaGovernance.sol";

import {ILimaSwap} from "./interfaces/ILimaSwap.sol";
import {IAmunUser} from "./interfaces/IAmunUser.sol";

/**
 * @title LimaToken
 * @author Lima Protocol
 *
 * Standard LimaToken.
 */
contract LimaTokenStorage is OwnableUpgradeSafe, OwnableLimaGovernance {
    using AddressArrayUtils for address[];
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant MAX_UINT256 = 2**256 - 1;
    address public constant USDC = address(
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    );

    // List of UnderlyingTokens
    address[] public underlyingTokens;
    address public currentUnderlyingToken;

    // address public owner;
    ILimaSwap public limaSwap;
    address public limaToken;

    //Fees
    address public feeWallet;
    uint256 public burnFee; // 1 / burnFee * burned amount == fee
    uint256 public mintFee; // 1 / mintFee * minted amount == fee
    uint256 public performanceFee;

    //Rebalance
    uint256 public lastUnderlyingBalancePer1000;
    uint256 public lastRebalance;
    uint256 public rebalanceInterval;


    /**
     * @dev Initializes contract
     */
    function __LimaTokenStorage_init_unchained(
        address _limaSwap,
        address _feeWallet,
        address _currentUnderlyingToken,
        address[] memory _underlyingTokens,
        uint256 _mintFee,
        uint256 _burnFee,
        uint256 _performanceFee
    ) public initializer {
        require(
            _underlyingTokens.contains(_currentUnderlyingToken),
            "_currentUnderlyingToken must be part of _underlyingTokens."
        );
        __Ownable_init();

        limaSwap = ILimaSwap(_limaSwap);

        __OwnableLimaGovernance_init_unchained();

        underlyingTokens = _underlyingTokens;
        currentUnderlyingToken = _currentUnderlyingToken;
        burnFee = _burnFee; //1/100 = 1%
        mintFee = _mintFee;
        performanceFee = _performanceFee; //1/10 = 10%
        rebalanceInterval = 24 hours;
        lastRebalance = now;
        lastUnderlyingBalancePer1000 = 0;
        feeWallet = _feeWallet;
    }

    /**
     * @dev Throws if called by any account other than the limaGovernance.
     */
    modifier onlyLimaGovernanceOrOwner() {
        _isLimaGovernanceOrOwner();
        _;
    }

    function _isLimaGovernanceOrOwner() internal view {
        require(
            limaGovernance() == _msgSender() ||
                owner() == _msgSender() ||
                limaToken == _msgSender(),
            "LS2" //"Ownable: caller is not the limaGovernance or owner"
        );
    }

    modifier onlyUnderlyingToken(address _token) {
        // Internal function used to reduce bytecode size
        _isUnderlyingToken(_token);
        _;
    }

    function _isUnderlyingToken(address _token) internal view {
        require(
            isUnderlyingTokens(_token),
            "LS3" //"Only token that are part of Underlying Tokens"
        );
    }

    modifier noEmptyAddress(address _address) {
        // Internal function used to reduce bytecode size
        require(_address != address(0), "LS4"); //Only address that is not empty");
        _;
    }

    /* ============ Setter ============ */

    function addUnderlyingToken(address _underlyingToken)
        external
        onlyLimaGovernanceOrOwner
    {
        require(
            !isUnderlyingTokens(_underlyingToken),
            "LS1" //"Can not add already existing underlying token again."
        );

        underlyingTokens.push(_underlyingToken);
    }

    function removeUnderlyingToken(address _underlyingToken)
        external
        onlyLimaGovernanceOrOwner
    {
        underlyingTokens = underlyingTokens.remove(_underlyingToken);
    }

    function setCurrentUnderlyingToken(address _currentUnderlyingToken)
        external
        onlyUnderlyingToken(_currentUnderlyingToken)
        onlyLimaGovernanceOrOwner
    {
        currentUnderlyingToken = _currentUnderlyingToken;
    }

    function setLimaToken(address _limaToken)
        external
        noEmptyAddress(_limaToken)
        onlyLimaGovernanceOrOwner
    {
        limaToken = _limaToken;
    }

    function setLimaSwap(address _limaSwap)
        public
        noEmptyAddress(_limaSwap)
        onlyLimaGovernanceOrOwner
    {
        limaSwap = ILimaSwap(_limaSwap);
    }

    function setFeeWallet(address _feeWallet)
        external
        noEmptyAddress(_feeWallet)
        onlyLimaGovernanceOrOwner
    {
        feeWallet = _feeWallet;
    }

    function setPerformanceFee(uint256 _performanceFee)
        external
        onlyLimaGovernanceOrOwner
    {
        performanceFee = _performanceFee;
    }

    function setBurnFee(uint256 _burnFee) external onlyLimaGovernanceOrOwner {
        burnFee = _burnFee;
    }

    function setMintFee(uint256 _mintFee) external onlyLimaGovernanceOrOwner {
        mintFee = _mintFee;
    }

    function setLastUnderlyingBalancePer1000(
        uint256 _lastUnderlyingBalancePer1000
    ) external onlyLimaGovernanceOrOwner {
        lastUnderlyingBalancePer1000 = _lastUnderlyingBalancePer1000;
    }

    function setLastRebalance(uint256 _lastRebalance)
        external
        onlyLimaGovernanceOrOwner
    {
        lastRebalance = _lastRebalance;
    }

    function setRebalanceInterval(uint256 _rebalanceInterval)
        external
        onlyLimaGovernanceOrOwner
    {
        rebalanceInterval = _rebalanceInterval;
    }

    /* ============ View ============ */

    function isUnderlyingTokens(address _underlyingToken)
        public
        view
        returns (bool)
    {
        return underlyingTokens.contains(_underlyingToken);
    }
}
