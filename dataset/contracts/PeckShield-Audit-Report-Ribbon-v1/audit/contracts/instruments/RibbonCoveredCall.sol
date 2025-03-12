// SPDX-License-Identifier: MIT
pragma solidity >=0.7.2;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {DSMath} from "../lib/DSMath.sol";

import {
    ProtocolAdapterTypes,
    IProtocolAdapter
} from "../adapters/IProtocolAdapter.sol";
import {ProtocolAdapter} from "../adapters/ProtocolAdapter.sol";
import {IRibbonFactory} from "../interfaces/IRibbonFactory.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {ISwap} from "../interfaces/ISwap.sol";
import {OtokenInterface} from "../interfaces/GammaInterface.sol";
import {OptionsVaultStorage} from "../storage/OptionsVaultStorage.sol";

contract RibbonCoveredCall is DSMath, OptionsVaultStorage {
    using ProtocolAdapter for IProtocolAdapter;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    string private constant _adapterName = "OPYN_GAMMA";
    string private constant _tokenName = "Ribbon ETH Theta Vault";
    string private constant _tokenSymbol = "rETH-THETA";

    IRibbonFactory public immutable factory;
    IProtocolAdapter public immutable adapter;
    address public immutable WETH;
    address public immutable USDC;

    // AirSwap Swap contract https://github.com/airswap/airswap-protocols/blob/master/source/swap/contracts/interfaces/ISwap.sol
    ISwap public immutable SWAP_CONTRACT;

    // 90% locked in options protocol, 10% of the pool reserved for withdrawals
    uint256 public constant lockedRatio = 0.9 ether;

    uint256 public constant delay = 1 days;

    event ManagerChanged(address oldManager, address newManager);

    event Deposit(address indexed account, uint256 amount, uint256 share);

    event Withdraw(
        address indexed account,
        uint256 amount,
        uint256 share,
        uint256 fee
    );

    event OpenShort(
        address indexed options,
        uint256 depositAmount,
        address manager
    );

    event CloseShort(
        address indexed options,
        uint256 withdrawAmount,
        address manager
    );

    event WithdrawalFeeSet(uint256 oldFee, uint256 newFee);

    event CapSet(uint256 oldCap, uint256 newCap, address manager);

    /**
     * @notice Initializes the factory and adapter contract addresses
     * It's important to bake the _factory variable into the contract with the constructor
     * If we do it in the `initialize` function, users get to set the factory variable and
     * subsequently the adapter, which allows them to make a delegatecall, then selfdestruct the contract.
     */
    constructor(
        address _factory,
        address _weth,
        address _usdc,
        address _swapContract
    ) {
        require(_factory != address(0), "!_factory");
        require(_weth != address(0), "!_weth");
        require(_usdc != address(0), "!_usdc");
        require(_swapContract != address(0), "!_swapContract");
        IRibbonFactory factoryInstance = IRibbonFactory(_factory);

        address adapterAddr = factoryInstance.getAdapter(_adapterName);
        require(adapterAddr != address(0), "Adapter not set");

        factory = factoryInstance;
        adapter = IProtocolAdapter(adapterAddr);
        WETH = _weth;
        USDC = _usdc;
        SWAP_CONTRACT = ISwap(_swapContract);
    }

    /**
     * @notice Initializes the OptionVault contract with an owner and a factory.
     * @param _owner is the owner of the contract who can set the manager
     * @param _initCap is the initial vault's cap on deposits, the manager can increase this as necessary
     */
    function initialize(
        address _asset,
        address _owner,
        address _feeRecipient,
        uint256 _initCap
    ) external initializer {
        require(_owner != address(0), "!_owner");
        require(_feeRecipient != address(0), "!_feeRecipient");
        require(_initCap > 0, "_initCap > 0");
        require(_asset != address(0), "!_asset");

        __ReentrancyGuard_init();
        __ERC20_init(_tokenName, _tokenSymbol);
        __Ownable_init();
        transferOwnership(_owner);
        cap = _initCap;

        // hardcode the initial withdrawal fee
        instantWithdrawalFee = 0.005 ether;
        feeRecipient = _feeRecipient;
        asset = _asset;
    }

    /**
     * @notice Sets the new manager of the vault. Revoke the airswap signer authorization from the old manager, and authorize the manager.
     * @param newManager is the new manager of the vault
     */
    function setManager(address newManager) external onlyOwner {
        require(newManager != address(0), "!newManager");
        address oldManager = manager;
        manager = newManager;

        emit ManagerChanged(oldManager, newManager);

        if (oldManager != address(0)) {
            SWAP_CONTRACT.revokeSigner(oldManager);
        }
        SWAP_CONTRACT.authorizeSigner(newManager);
    }

    /**
     * @notice Sets the new fee recipient
     * @param newFeeRecipient is the address of the new fee recipient
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != address(0), "!newFeeRecipient");
        feeRecipient = newFeeRecipient;
    }

    /**
     * @notice Sets the new withdrawal fee
     * @param newWithdrawalFee is the fee paid in tokens when withdrawing
     */
    function setWithdrawalFee(uint256 newWithdrawalFee) external onlyManager {
        require(newWithdrawalFee > 0, "withdrawalFee != 0");

        // cap max withdrawal fees to 100% of the withdrawal amount
        require(newWithdrawalFee < 1 ether, "withdrawalFee >= 100%");

        uint256 oldFee = instantWithdrawalFee;
        emit WithdrawalFeeSet(oldFee, newWithdrawalFee);

        instantWithdrawalFee = newWithdrawalFee;
    }

    /**
     * @notice Deposits ETH into the contract and mint vault shares. Reverts if the underlying is not WETH.
     */
    function depositETH() external payable nonReentrant {
        require(asset == WETH, "asset is not WETH");
        require(msg.value > 0, "No value passed");

        IWETH(WETH).deposit{value: msg.value}();
        _deposit(msg.value);
    }

    /**
     * @notice Deposits the `asset` into the contract and mint vault shares.
     * @param amount is the amount of `asset` to deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        _deposit(amount);
    }

    /**
     * @notice Mints the vault shares to the msg.sender
     * @param amount is the amount of `asset` deposited
     */
    function _deposit(uint256 amount) private {
        uint256 totalWithDepositedAmount = totalBalance();
        require(totalWithDepositedAmount < cap, "Cap exceeded");

        // amount needs to be subtracted from totalBalance because it has already been
        // added to it from either IWETH.deposit and IERC20.safeTransferFrom
        uint256 total = totalWithDepositedAmount.sub(amount);

        uint256 shareSupply = totalSupply();

        // Following the pool share calculation from Alpha Homora: https://github.com/AlphaFinanceLab/alphahomora/blob/340653c8ac1e9b4f23d5b81e61307bf7d02a26e8/contracts/5/Bank.sol#L104
        uint256 share =
            shareSupply == 0 ? amount : amount.mul(shareSupply).div(total);

        emit Deposit(msg.sender, amount, share);

        _mint(msg.sender, share);
    }

    /**
     * @notice Withdraws ETH from vault using vault shares
     * @param share is the number of vault shares to be burned
     */
    function withdrawETH(uint256 share) external nonReentrant {
        require(asset == WETH, "!WETH");
        uint256 withdrawAmount = _withdraw(share);

        IWETH(WETH).withdraw(withdrawAmount);
        (bool success, ) = msg.sender.call{value: withdrawAmount}("");
        require(success, "ETH transfer failed");
    }

    /**
     * @notice Withdraws WETH from vault using vault shares
     * @param share is the number of vault shares to be burned
     */
    function withdraw(uint256 share) external nonReentrant {
        uint256 withdrawAmount = _withdraw(share);
        IERC20(asset).safeTransfer(msg.sender, withdrawAmount);
    }

    /**
     * @notice Burns vault shares and checks if eligible for withdrawal
     * @param share is the number of vault shares to be burned
     */
    function _withdraw(uint256 share) private returns (uint256) {
        (uint256 amountAfterFee, uint256 feeAmount) =
            withdrawAmountWithShares(share);

        emit Withdraw(msg.sender, amountAfterFee, share, feeAmount);

        _burn(msg.sender, share);
        IERC20(asset).safeTransfer(feeRecipient, feeAmount);

        return amountAfterFee;
    }

    /**
     * @notice Sets the next option address and the timestamp at which the admin can call `rollToNextOption` to open a short for the option
     * @param optionTerms is the terms of the option contract
     */
    function setNextOption(
        ProtocolAdapterTypes.OptionTerms calldata optionTerms
    ) external onlyManager nonReentrant {
        address option = adapter.getOptionsAddress(optionTerms);
        require(option != address(0), "!option");
        OtokenInterface otoken = OtokenInterface(option);
        require(otoken.underlyingAsset() == asset, "!asset");
        require(otoken.strikeAsset() == USDC, "strikeAsset != USDC"); // we just assume all options use USDC as the strike

        uint256 readyAt = block.timestamp.add(delay);
        require(
            otoken.expiryTimestamp() >= readyAt,
            "Option expiry cannot be before delay"
        );

        nextOption = option;
        nextOptionReadyAt = readyAt;
    }

    /**
     * @notice Rolls from one short option position to another. Closes the expired short position, withdraw from it, then open a new position.
     */
    function rollToNextOption() external onlyManager nonReentrant {
        address oldOption = currentOption;
        address newOption = nextOption;
        require(newOption != address(0), "No found option");
        require(block.timestamp > nextOptionReadyAt, "Delay not passed");

        currentOption = newOption;

        if (oldOption != address(0)) {
            uint256 withdrawAmount = adapter.delegateCloseShort();
            emit CloseShort(oldOption, withdrawAmount, msg.sender);
        }
        uint256 currentBalance = IERC20(asset).balanceOf(address(this));
        uint256 shortAmount = wmul(currentBalance, lockedRatio);
        lockedAmount = shortAmount;

        OtokenInterface otoken = OtokenInterface(newOption);

        ProtocolAdapterTypes.OptionTerms memory optionTerms =
            ProtocolAdapterTypes.OptionTerms(
                asset,
                USDC,
                otoken.collateralAsset(),
                otoken.expiryTimestamp(),
                otoken.strikePrice().mul(10**10), // scale back to 10**18
                ProtocolAdapterTypes.OptionType.Call, // isPut
                address(0)
            );

        uint256 shortBalance =
            adapter.delegateCreateShort(optionTerms, shortAmount);
        IERC20 optionToken = IERC20(newOption);
        optionToken.safeApprove(address(SWAP_CONTRACT), shortBalance);

        emit OpenShort(newOption, shortAmount, msg.sender);
    }

    /**
     * @notice Withdraw from the options protocol by closing short in an event of a emergency
     */
    function emergencyWithdrawFromShort() external onlyManager nonReentrant {
        address oldOption = currentOption;
        require(oldOption != address(0), "!currentOption");

        currentOption = address(0);
        nextOption = address(0);

        uint256 withdrawAmount = adapter.delegateCloseShort();
        emit CloseShort(oldOption, withdrawAmount, msg.sender);
    }

    /**
     * @notice Sets a new cap for deposits
     * @param newCap is the new cap for deposits
     */
    function setCap(uint256 newCap) external onlyManager {
        uint256 oldCap = cap;
        cap = newCap;
        emit CapSet(oldCap, newCap, msg.sender);
    }

    /**
     * @notice Returns the expiry of the current option the vault is shorting
     */
    function currentOptionExpiry() external view returns (uint256) {
        address _currentOption = currentOption;
        if (_currentOption == address(0)) {
            return 0;
        }

        OtokenInterface oToken = OtokenInterface(currentOption);
        return oToken.expiryTimestamp();
    }

    /**
     * @notice Returns the amount withdrawable (in `asset` tokens) using the `share` amount
     * @param share is the number of shares burned to withdraw asset from the vault
     * @return amountAfterFee is the amount of asset tokens withdrawable from the vault
     * @return feeAmount is the fee amount (in asset tokens) sent to the feeRecipient
     */
    function withdrawAmountWithShares(uint256 share)
        public
        view
        returns (uint256 amountAfterFee, uint256 feeAmount)
    {
        uint256 currentAssetBalance = assetBalance();
        uint256 total = lockedAmount.add(currentAssetBalance);

        // Following the pool share calculation from Alpha Homora: https://github.com/AlphaFinanceLab/alphahomora/blob/340653c8ac1e9b4f23d5b81e61307bf7d02a26e8/contracts/5/Bank.sol#L111
        uint256 withdrawAmount = share.mul(total).div(totalSupply());
        require(
            withdrawAmount <= currentAssetBalance,
            "Cannot withdraw more than available"
        );

        feeAmount = wmul(withdrawAmount, instantWithdrawalFee);
        amountAfterFee = withdrawAmount.sub(feeAmount);
    }

    function maxWithdrawableShares() public view returns (uint256) {
        uint256 withdrawableBalance = assetBalance();
        uint256 total = lockedAmount.add(assetBalance());
        return withdrawableBalance.mul(totalSupply()).div(total);
    }

    /**
     * @notice Returns the max amount withdrawable by an account using the account's vault share balance
     * @param account is the address of the vault share holder
     * @return amount of `asset` withdrawable from vault, with fees accounted
     */
    function maxWithdrawAmount(address account)
        external
        view
        returns (uint256)
    {
        uint256 maxShares = maxWithdrawableShares();
        uint256 share = balanceOf(account);
        uint256 numShares = min(maxShares, share);

        (uint256 withdrawAmount, ) = withdrawAmountWithShares(numShares);
        return withdrawAmount;
    }

    /**
     * @notice Returns the vault's total balance, including the amounts locked into a short position
     * @return total balance of the vault, including the amounts locked in third party protocols
     */
    function totalBalance() public view returns (uint256) {
        return lockedAmount.add(IERC20(asset).balanceOf(address(this)));
    }

    /**
     * @notice Returns the asset balance on the vault. This balance is freely withdrawable by users.
     */
    function assetBalance() public view returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }

    /**
     * @notice Returns the token decimals
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /**
     * @notice Only allows manager to execute a function
     */
    modifier onlyManager {
        require(msg.sender == manager, "Only manager");
        _;
    }
}
