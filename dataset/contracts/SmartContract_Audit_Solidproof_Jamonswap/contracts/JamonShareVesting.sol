// SPDX-License-Identifier: MIT
pragma solidity =0.8.11;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IERC20MintBurn.sol";
import "./interfaces/IJamonShareVesting.sol";
import "./interfaces/IJamonVesting.sol";

/**
 * @title JamonShareVesting
 * @notice Block and mine JamonShare tokens to reward liquidity contributions.
 */
contract JamonShareVesting is
    IJamonShareVesting,
    ReentrancyGuard,
    Pausable,
    Ownable
{
    //---------- Libraries ----------//
    using SafeMath for uint256;
    using SafeERC20 for IERC20MintBurn;

    //---------- Contracts ----------//
    IERC20MintBurn internal JamonShare; // JamonShare token contract.
    IJamonVesting internal JamonVesting; // JamonV2 vesting contract.

    //---------- Variables ----------//
    address private Presale; // Addres of the JamonShare presale contract.
    uint256 constant month = 2629743; // 1 Month Timestamp 2629743

    //---------- Storage -----------//

    mapping(address => uint256) internal SHARE_VESTING; // Uint256 map of the balances vested.

    //---------- Events -----------//
    event Vested(address indexed wallet, uint256 amount);
    event Released(address indexed wallet, uint256 amount);

    //---------- Constructor ----------//
    constructor(address jamonShare_) {
        require(jamonShare_ != address(0x0), "Invalid address");
        JamonShare = IERC20MintBurn(jamonShare_);
    }

    function initialize(address presale_, address jamonVesting_)
        external
        onlyOwner
    {
        require(
            presale_ != address(0x0) && jamonVesting_ != address(0x0),
            "Invalid address"
        );
        require(Presale == address(0x0), "Already initialized");
        Presale = presale_;
        JamonVesting = IJamonVesting(jamonVesting_);
    }

    //---------- Modifiers ----------//
    /**
     * @dev Reverts if the caller is not the presale contract.
     */
    modifier onlyPresale() {
        require(_msgSender() == Presale, "Forbidden address");
        _;
    }

    //----------- External Functions -----------//
    /**
     * @notice Check vesting info for a wallet.
     * @return amount of tokens vested.
     */
    function shareInfo(address wallet_) external view returns (uint256) {
        return SHARE_VESTING[wallet_];
    }

    /**
     * @notice Add a new vesting, mint the tokens for receive at moment of vesting and block the rest for the end of distribution time.
     * @param wallet_ address who receives the tokens.
     * @param jsNow_  amount of tokens to receive at the time of the contribution.
     * @param jsEnd_ amount to receive once the distribution time is over.
     */
    function createVesting(
        address wallet_,
        uint256 jsNow_,
        uint256 jsEnd_
    ) external override whenNotPaused onlyPresale {
        JamonShare.mint(wallet_, jsNow_);
        SHARE_VESTING[wallet_] += jsEnd_;
        emit Vested(wallet_, jsEnd_);
    }

    /**
     * @notice Withdraw pending tokens after the distribution period ends.
     */
    function claimShare() external nonReentrant {
        require(JamonVesting.depositsCount() == 12, "Shares lockeds");
        uint256 amount = SHARE_VESTING[_msgSender()];
        require(amount > 0, "Zero amount");
        delete SHARE_VESTING[_msgSender()];
        JamonShare.mint(_msgSender(), amount);
        emit Released(_msgSender(), amount);
    }

    /**
     * @notice Functions for pause and unpause the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
