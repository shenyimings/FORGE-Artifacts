// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20UniswapV2InternalSwaps} from "./ERC20UniswapV2InternalSwaps.sol";

contract TheTribe is ERC20, Ownable, ERC20UniswapV2InternalSwaps {
    /** @notice The presale states. */
    enum PresaleState {
        NONE,
        OPEN,
        CLOSED,
        COMPLETED
    }

    /** @notice Percentage of supply allocated for presale participants (60%). */
    uint256 public constant SHARE_PRESALE = 60_00;
    /** @notice Percentage of supply allocated for initial liquidity (28.5%).*/
    uint256 public constant SHARE_LIQUIDITY = 28_50;
    /** @notice Percentage of supply allocated for team, marketing, cex listings, etc. (11.5%). */
    uint256 public constant SHARE_OTHER = 11_50;
    /** @notice Per account limit in ETH for presale (1 ETH). */
    uint256 public constant PRESALE_ACCOUNT_LIMIT = 1 ether;
    /** @notice Minimum threshold in ETH to trigger #_swapTokens. */
    uint256 public constant SWAP_THRESHOLD_ETH_MIN = 0.005 ether;
    /** @notice Maximum threshold in ETH to trigger #_swapTokens. */
    uint256 public constant SWAP_THRESHOLD_ETH_MAX = 50 ether;
    /** @notice Maximum tax (0.25%) */
    uint256 public constant MAX_TAX = 25;

    uint256 private constant _MAX_SUPPLY = 1_000_000_000 ether;
    uint256 private constant _SUPPLY_PRESALE =
        (_MAX_SUPPLY * SHARE_PRESALE) / 100_00;
    uint256 private constant _SUPPLY_LIQUIDITY =
        (_MAX_SUPPLY * SHARE_LIQUIDITY) / 100_00;
    uint256 private constant _SUPPLY_OTHER =
        _MAX_SUPPLY - _SUPPLY_PRESALE - _SUPPLY_LIQUIDITY;
    uint256 private constant _LAUNCH_BUY_TAX = 3_00;
    uint256 private constant _LAUNCH_SELL_TAX = 50_00;
    uint256 private constant _LAUNCH_TAX_WINDOW = 20 minutes;

    /** @notice Tax recipient wallet. */
    address public taxRecipient;
    /** @notice Whether address is extempt from transfer tax. */
    mapping(address => bool) public taxFreeAccount;
    /** @notice Whether address is an exchange pool. */
    mapping(address => bool) public isExchangePool;
    /** @notice Threshold in ETH of tokens to collect before triggering #_swapTokens. */
    uint256 public swapThresholdEth = 0.1 ether;
    /** @notice Tax manager. */
    address public taxManager;
    /** @notice Buy tax in bps (0%). In first 20 minutes after adding liquidity, buy tax will be 3%. */
    uint256 public buyTax = 0;
    /** @notice Sell tax in bps (0.25%). In first 20 minutes after adding liquidity, sell tax will be 50%. */
    uint256 public sellTax = 25;
    /** @notice Presale commitment in ETH per address. */
    mapping(address => uint256) public commitment;
    /** @notice Presale amount of claimed tokens per address. */
    mapping(address => uint256) public claimedTokens;
    /** @notice Presale total commitment in ETH. */
    uint256 public totalCommitments;
    /** @notice Presale total amount of claimed tokens. */
    uint256 public totalClaimed;
    /** @notice Current presale state. */
    PresaleState public presaleState;

    uint256 private _launchTaxEndsAt = type(uint256).max;

    event CommitedToPresale(address indexed account, uint256 amount);
    event PresaleOpened();
    event PresaleClosed(uint256 totalCommitments);
    event PresaleCompleted(uint256 totalCommitments);
    event PresaleClaimed(address indexed account, uint256 amount);
    event TaxRecipientChanged(address indexed taxRecipient);
    event SwapThresholdChanged(uint256 swapThresholdEth);
    event TaxFreeStateChanged(address indexed account, bool indexed taxFree);
    event ExchangePoolStateChanged(
        address indexed account,
        bool indexed isExchangePool
    );
    event TaxManagerChanged(address indexed taxManager);
    event TaxesChanged(uint256 newBuyTax, uint256 newSellTax);
    event TaxesWithdrawn(uint256 amount);

    error MaxAccountLimitExceeded();
    error PresaleIsClosed();
    error PresaleNotCompleted();
    error AlreadyClaimed();
    error NoCommittments();
    error NothingCommitted();
    error Unauthorized();
    error InvalidParameters();
    error InvalidSwapThreshold();
    error InvalidTax();
    error NoContract();
    error InvalidState();

    modifier onlyTaxManager() {
        if (msg.sender != taxManager) {
            revert Unauthorized();
        }
        _;
    }

    constructor(
        address _owner,
        address _taxRecipient,
        address _taxManager
    ) ERC20("The Tribe", "TRIBE") Ownable(_owner) {
        taxManager = _taxManager;
        emit TaxManagerChanged(_taxManager);
        taxRecipient = _taxRecipient;
        emit TaxRecipientChanged(_taxRecipient);

        taxFreeAccount[address(0)] = true;
        emit TaxFreeStateChanged(address(0), true);
        taxFreeAccount[_taxRecipient] = true;
        emit TaxFreeStateChanged(_taxRecipient, true);
        taxFreeAccount[address(this)] = true;
        emit TaxFreeStateChanged(address(this), true);
        isExchangePool[pair] = true;
        emit ExchangePoolStateChanged(pair, true);
        emit TaxesChanged(buyTax, sellTax);

        _mint(address(this), _SUPPLY_PRESALE + _SUPPLY_LIQUIDITY);
        _mint(_taxRecipient, _SUPPLY_OTHER);
    }

    /** @dev Users can send ETH directly to **this** contract to participate */
    receive() external payable {
        commitToPresale();
    }

    // *** User Interface ***

    /**
     * @notice Commit ETH to presale.
     * Presale supply is claimable proportionally for all presale participants.
     * Presale has no hardcap and 1 ETH per wallet limit.
     * Users can also send ETH directly to **this** contract to participate.
     * @dev Callable once presaleOpen.
     */
    function commitToPresale() public payable {
        address account = msg.sender;
        if (_isContract(account)) {
            revert NoContract();
        }
        if (
            presaleState != PresaleState.OPEN
        ) {
            revert PresaleIsClosed();
        }

        commitment[account] += msg.value;
        totalCommitments += msg.value;

        if (commitment[account] > PRESALE_ACCOUNT_LIMIT) {
            revert MaxAccountLimitExceeded();
        }

        emit CommitedToPresale(account, msg.value);
    }

    /**
     * @notice Claim callers presale tokens.
     * @dev Callable once presaleCompleted.
     */
    function claimPresale() external {
        address account = msg.sender;

        if (_isContract(account)) {
            revert NoContract();
        }
        if (presaleState != PresaleState.COMPLETED) {
            revert PresaleNotCompleted();
        }
        if (commitment[account] == 0) {
            revert NothingCommitted();
        }
        if (claimedTokens[account] != 0) {
            revert AlreadyClaimed();
        }

        uint256 amountTokens = (_SUPPLY_PRESALE * commitment[account]) /
            totalCommitments;
        claimedTokens[account] = amountTokens;
        totalClaimed += amountTokens;

        _transferFromContractBalance(account, amountTokens);

        emit PresaleClaimed(account, amountTokens);
    }

    /** @notice Returns amount of tokens to be claimed by presale participants. */
    function unclaimedSupply() external view returns (uint256) {
        return _SUPPLY_PRESALE - totalClaimed;
    }


    // *** Owner Interface ***

    /**
     * @notice Open presale for all users.
     */
    function openPresale() external onlyOwner {
        if (presaleState != PresaleState.NONE) {
            revert InvalidState();
        }
        presaleState = PresaleState.OPEN;
        emit PresaleOpened();
    }

    /**
     * @notice Close the presale.
     * Called after #openPresale.
     */
    function closePresale() external onlyOwner {
        if (presaleState != PresaleState.OPEN) {
            revert InvalidState();
        }
        if (totalCommitments == 0) {
            revert NoCommittments();
        }

        presaleState = PresaleState.CLOSED;

        emit PresaleClosed(totalCommitments);
    }

    /**
     * @notice Complete the presale.
     * @dev Adds 47.5% of collected ETH with 28.5% of totalSupply to Liquidity.
     * Sends the remaining 52.5% of collected ETH to current owner.
     * Renounces ownership.
     * Called after #closePresale.
     */
    function completePresale() external onlyOwner {
        if (presaleState != PresaleState.CLOSED) {
            revert InvalidState();
        }

        uint256 amountEthForLiquidity = (totalCommitments * _SUPPLY_LIQUIDITY) /
            _SUPPLY_PRESALE;
        _addInitialLiquidityEth(
            _SUPPLY_LIQUIDITY,
            amountEthForLiquidity,
            taxRecipient
        );

        _sweepEth(taxRecipient);

        _launchTaxEndsAt = block.timestamp + _LAUNCH_TAX_WINDOW;
        renounceOwnership();

        presaleState = PresaleState.COMPLETED;

        emit PresaleCompleted(totalCommitments);
    }

    // *** Tax Manager Interface ***

    /**
     * @notice Set `taxFree` state of `account`.
     * @param account account
     * @param taxFree true if `account` should be extempt from transfer taxes.
     * @dev Only callable by taxManager.
     */
    function setTaxFreeAccount(
        address account,
        bool taxFree
    ) external onlyTaxManager {
        if (taxFreeAccount[account] == taxFree) {
            revert InvalidParameters();
        }
        taxFreeAccount[account] = taxFree;
        emit TaxFreeStateChanged(account, taxFree);
    }

    /**
     * @notice Set `exchangePool` state of `account`
     * @param account account
     * @param exchangePool whether `account` is an exchangePool
     * @dev ExchangePool state is used to decide if transfer is a swap
     * and should trigger #_swapTokens.
     */
    function setExchangePool(
        address account,
        bool exchangePool
    ) external onlyTaxManager {
        if (isExchangePool[account] == exchangePool) {
            revert InvalidParameters();
        }
        isExchangePool[account] = exchangePool;
        emit ExchangePoolStateChanged(account, exchangePool);
    }

    /**
     * @notice Transfer taxManager role to `newTaxManager`.
     * @param newTaxManager new taxManager
     * @dev Only callable by taxManager.
     */
    function transferTaxManager(address newTaxManager) external onlyTaxManager {
        if (newTaxManager == taxManager) {
            revert InvalidParameters();
        }
        taxManager = newTaxManager;
        emit TaxManagerChanged(newTaxManager);
    }

    /**
     * @notice Set taxRecipient address to `newTaxRecipient`.
     * @param newTaxRecipient new taxRecipient
     * @dev Only callable by taxManager.
     */
    function setTaxRecipient(address newTaxRecipient) external onlyTaxManager {
        if (newTaxRecipient == taxRecipient) {
            revert InvalidParameters();
        }
        taxRecipient = newTaxRecipient;
        emit TaxRecipientChanged(newTaxRecipient);
    }

    /**
     * @notice Withdraw tax collected (which would usually be automatically swapped to weth) to taxRecipient
     * @dev Only callable by taxManager.
     */
    function withdrawTaxes() external onlyTaxManager {
        uint256 balance = balanceOf(address(this));
        if (balance > 0) {
            super._transfer(address(this), taxRecipient, balance);
            emit TaxesWithdrawn(balance);
        }
    }

    /**
     * @notice Change the amount of tokens collected via tax before a swap is triggered.
     * @param newSwapThresholdEth new threshold received in ETH
     * @dev Only callable by taxManager
     */
    function setSwapThresholdEth(
        uint256 newSwapThresholdEth
    ) external onlyTaxManager {
        if (
            newSwapThresholdEth < SWAP_THRESHOLD_ETH_MIN ||
            newSwapThresholdEth > SWAP_THRESHOLD_ETH_MAX ||
            newSwapThresholdEth == swapThresholdEth
        ) {
            revert InvalidSwapThreshold();
        }
        swapThresholdEth = newSwapThresholdEth;
        emit SwapThresholdChanged(newSwapThresholdEth);
    }

    /**
     * @notice Set tax for buying and selling the token
     * @param newBuyTax new buy tax in bps
     * @param newSellTax new sell tax in bps
     * @dev Only callable by taxManager
     */
    function changeTaxes(
        uint256 newBuyTax,
        uint256 newSellTax
    ) external onlyTaxManager {
        if (newBuyTax > MAX_TAX || newSellTax > MAX_TAX) {
            revert InvalidTax();
        }
        buyTax = newBuyTax;
        sellTax = newSellTax;
        emit TaxesChanged(newBuyTax, newSellTax);
    }

    /**
     * @notice Threshold of how many tokens to collect from tax before calling #swapTokens.
     * @dev Depends on swapThresholdEth which can be configured by taxManager.
     * Restricted to 5% of liquidity.
     */
    function swapThresholdToken() public view returns (uint256) {
        (uint reserveToken, uint reserveWeth) = _getReserve();
        uint256 maxSwapEth = (reserveWeth * 5) / 100;
        return
            _getAmountToken(
                swapThresholdEth > maxSwapEth ? maxSwapEth : swapThresholdEth,
                reserveToken,
                reserveWeth
            );
    }

    /** @notice Get current buy tax depending on current timestamp. */
    function currentBuyTax() public view returns (uint256) {
        return _getTax(true);
    }

    /** @notice Get current buy tax depending on current timestamp. */
    function currentSellTax() public view returns (uint256) {
        return _getTax(false);
    }


    // *** Internal Interface ***

    /** @notice IERC20#_transfer */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (
            !taxFreeAccount[from] &&
            !taxFreeAccount[to] &&
            !taxFreeAccount[msg.sender]
        ) {
            uint256 fee = amount * _getTax(isExchangePool[from]) / 100_00;
            super._update(from, address(this), fee);
            unchecked {
                amount -= fee;
            }

            if (isExchangePool[to]) /* selling */ {
                _swapTokens(swapThresholdToken());
            }
        }
        super._update(from, to, amount);
    }


    /** @dev Get transfer tax depending on current timestamp and `isBuy`. */
    function _getTax(bool isBuy) private view returns (uint256) {
        return
            isBuy
                ? (
                    block.timestamp < _launchTaxEndsAt
                        ? _LAUNCH_BUY_TAX
                        : buyTax
                )
                : (
                    block.timestamp < _launchTaxEndsAt
                        ? _LAUNCH_SELL_TAX
                        : sellTax
                );
    }

    /** @dev Transfer `amount` tokens from contract balance to `to`. */
    function _transferFromContractBalance(
        address to,
        uint256 amount
    ) internal override {
        super._update(address(this), to, amount);
    }

    /**
     * @notice Swap `amountToken` collected from tax to WETH to add to send to taxRecipient.
     */
    function _swapTokens(uint256 amountToken) internal {
        if (balanceOf(address(this)) + totalClaimed < amountToken + _SUPPLY_PRESALE) {
            return;
        }

        _swapForWETH(amountToken, taxRecipient);
    }
}
