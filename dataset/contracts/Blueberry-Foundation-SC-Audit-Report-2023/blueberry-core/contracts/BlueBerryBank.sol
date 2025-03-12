// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "./utils/BlueBerryConst.sol" as Constants;
import "./utils/BlueBerryErrors.sol" as Errors;
import "./utils/EnsureApprove.sol";
import "./utils/ERC1155NaiveReceiver.sol";
import "./interfaces/IBank.sol";
import "./interfaces/ICoreOracle.sol";
import "./interfaces/ISoftVault.sol";
import "./interfaces/IHardVault.sol";
import "./interfaces/compound/ICErc20.sol";
import "./libraries/BBMath.sol";

/**
 * @title BlueberryBank
 * @author BlueberryProtocol
 * @notice Blueberry Bank is the main contract that stores user's positions and track the borrowing of tokens
 */
contract BlueBerryBank is
    OwnableUpgradeable,
    ERC1155NaiveReceiver,
    IBank,
    EnsureApprove
{
    using BBMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private constant _NO_ID = type(uint256).max;
    address private constant _NO_ADDRESS = address(1);

    uint256 public _GENERAL_LOCK; // TEMPORARY: re-entrancy lock guard.
    uint256 public _IN_EXEC_LOCK; // TEMPORARY: exec lock guard.
    uint256 public POSITION_ID; // TEMPORARY: position ID currently under execution.
    address public SPELL; // TEMPORARY: spell currently under execution.

    IProtocolConfig public config;
    ICoreOracle public oracle; // The oracle address for determining prices.
    IFeeManager public feeManager;

    uint256 public nextPositionId; // Next available position ID, starting from 1 (see initialize).
    uint256 public bankStatus; // Each bit stores certain bank status, e.g. borrow allowed, repay allowed

    address[] public allBanks; // The list of all listed banks.
    mapping(address => Bank) public banks; // Mapping from token to bank data.
    mapping(address => bool) public bTokenInBank; // Mapping from bToken to its existence in bank.
    mapping(uint256 => Position) public positions; // Mapping from position ID to position data.

    bool public allowContractCalls; // The boolean status whether to allow call from contract (false = onlyEOA)
    mapping(address => bool) public whitelistedTokens; // Mapping from token to whitelist status
    mapping(address => bool) public whitelistedWrappedTokens; // Mapping from token to whitelist status
    mapping(address => bool) public whitelistedSpells; // Mapping from spell to whitelist status
    mapping(address => bool) public whitelistedContracts; // Mapping from user to whitelist status

    /// @dev Ensure that the function is called from EOA
    /// when allowContractCalls is set to false and caller is not whitelisted
    modifier onlyEOAEx() {
        if (!allowContractCalls && !whitelistedContracts[msg.sender]) {
            if (AddressUpgradeable.isContract(msg.sender))
                revert Errors.NOT_EOA(msg.sender);
        }
        _;
    }

    /// @dev Ensure that the token is already whitelisted
    modifier onlyWhitelistedToken(address token) {
        if (!whitelistedTokens[token])
            revert Errors.TOKEN_NOT_WHITELISTED(token);
        _;
    }

    /// @dev Ensure that the wrapped ERC1155 is already whitelisted
    modifier onlyWhitelistedERC1155(address token) {
        if (!whitelistedWrappedTokens[token])
            revert Errors.TOKEN_NOT_WHITELISTED(token);
        _;
    }

    /// @dev Reentrancy lock guard.
    modifier lock() {
        if (_GENERAL_LOCK != _NOT_ENTERED) revert Errors.LOCKED();
        _GENERAL_LOCK = _ENTERED;
        _;
        _GENERAL_LOCK = _NOT_ENTERED;
    }

    /// @dev Ensure that the function is called from within the execution scope.
    modifier inExec() {
        if (POSITION_ID == _NO_ID) revert Errors.NOT_IN_EXEC();
        if (SPELL != msg.sender) revert Errors.NOT_FROM_SPELL(msg.sender);
        if (_IN_EXEC_LOCK != _NOT_ENTERED) revert Errors.LOCKED();
        _IN_EXEC_LOCK = _ENTERED;
        _;
        _IN_EXEC_LOCK = _NOT_ENTERED;
    }

    /// @dev Ensure that the interest rate of the given token is accrued.
    modifier poke(address token) {
        accrue(token);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initialize the bank smart contract, using msg.sender as the first governor.
    /// @param oracle_ The oracle smart contract address.
    /// @param config_ The Protocol config address
    function initialize(
        ICoreOracle oracle_,
        IProtocolConfig config_
    ) external initializer {
        __Ownable_init();
        if (address(oracle_) == address(0) || address(config_) == address(0)) {
            revert Errors.ZERO_ADDRESS();
        }
        _GENERAL_LOCK = _NOT_ENTERED;
        _IN_EXEC_LOCK = _NOT_ENTERED;
        POSITION_ID = _NO_ID;
        SPELL = _NO_ADDRESS;

        config = config_;
        oracle = oracle_;
        feeManager = config_.feeManager();

        nextPositionId = 1;
        bankStatus = 15; // 0x1111: allow borrow, repay, lend, withdrawLend as default

        emit SetOracle(address(oracle_));
    }

    /// @dev Return the current executor (the owner of the current position).
    function EXECUTOR() external view override returns (address) {
        uint256 positionId = POSITION_ID;
        if (positionId == _NO_ID) {
            revert Errors.NOT_UNDER_EXECUTION();
        }
        return positions[positionId].owner;
    }

    /// @dev Set allowContractCalls
    /// @param ok The status to set allowContractCalls to (false = onlyEOA)
    function setAllowContractCalls(bool ok) external onlyOwner {
        allowContractCalls = ok;
    }

    /// @notice Set whitelist user status
    /// @param contracts list of users to change status
    /// @param statuses list of statuses to change to
    function whitelistContracts(
        address[] calldata contracts,
        bool[] calldata statuses
    ) external onlyOwner {
        if (contracts.length != statuses.length) {
            revert Errors.INPUT_ARRAY_MISMATCH();
        }
        for (uint256 idx = 0; idx < contracts.length; idx++) {
            if (contracts[idx] == address(0)) {
                revert Errors.ZERO_ADDRESS();
            }
            whitelistedContracts[contracts[idx]] = statuses[idx];
        }
    }

    /// @dev Set whitelist spell status
    /// @param spells list of spells to change status
    /// @param statuses list of statuses to change to
    function whitelistSpells(
        address[] calldata spells,
        bool[] calldata statuses
    ) external onlyOwner {
        if (spells.length != statuses.length) {
            revert Errors.INPUT_ARRAY_MISMATCH();
        }
        for (uint256 idx = 0; idx < spells.length; idx++) {
            if (spells[idx] == address(0)) {
                revert Errors.ZERO_ADDRESS();
            }
            whitelistedSpells[spells[idx]] = statuses[idx];
        }
    }

    /// @notice Set whitelist token status
    /// @param tokens list of tokens to change status
    /// @param statuses list of statuses to change to
    function whitelistTokens(
        address[] calldata tokens,
        bool[] calldata statuses
    ) external onlyOwner {
        if (tokens.length != statuses.length) {
            revert Errors.INPUT_ARRAY_MISMATCH();
        }
        for (uint256 idx = 0; idx < tokens.length; idx++) {
            if (statuses[idx] && !oracle.isTokenSupported(tokens[idx]))
                revert Errors.ORACLE_NOT_SUPPORT(tokens[idx]);
            whitelistedTokens[tokens[idx]] = statuses[idx];
            emit SetWhitelistToken(tokens[idx], statuses[idx]);
        }
    }

    /// @notice Whitelist ERC1155(wrapped tokens)
    /// @param tokens List of tokens to set whitelist status
    /// @param ok Whitelist status
    function whitelistERC1155(
        address[] memory tokens,
        bool ok
    ) external onlyOwner {
        for (uint256 idx = 0; idx < tokens.length; idx++) {
            address token = tokens[idx];
            if (token == address(0)) revert Errors.ZERO_ADDRESS();
            whitelistedWrappedTokens[token] = ok;
            emit SetWhitelistERC1155(token, ok);
        }
    }

    /**
     * @dev Add a new bank to the ecosystem.
     * @param token The underlying token for the bank.
     * @param softVault The address of softVault.
     * @param hardVault The address of hardVault.
     */
    function addBank(
        address token,
        address softVault,
        address hardVault,
        uint256 liqThreshold
    ) external onlyOwner onlyWhitelistedToken(token) {
        if (softVault == address(0) || hardVault == address(0))
            revert Errors.ZERO_ADDRESS();
        if (liqThreshold > Constants.DENOMINATOR)
            revert Errors.LIQ_THRESHOLD_TOO_HIGH(liqThreshold);
        if (liqThreshold < Constants.MIN_LIQ_THRESHOLD)
            revert Errors.LIQ_THRESHOLD_TOO_LOW(liqThreshold);

        Bank storage bank = banks[token];
        address bToken = address(ISoftVault(softVault).bToken());

        if (bTokenInBank[bToken]) revert Errors.BTOKEN_ALREADY_ADDED();
        if (bank.isListed) revert Errors.BANK_ALREADY_LISTED();
        if (allBanks.length >= 256) revert Errors.BANK_LIMIT();

        bTokenInBank[bToken] = true;
        bank.isListed = true;
        bank.index = uint8(allBanks.length);
        bank.bToken = bToken;
        bank.softVault = softVault;
        bank.hardVault = hardVault;
        bank.liqThreshold = liqThreshold;

        IHardVault(hardVault).setApprovalForAll(hardVault, true);
        allBanks.push(token);

        emit AddBank(token, bToken, softVault, hardVault);
    }

    /// @dev Set bank status
    /// @param _bankStatus new bank status to change to
    function setBankStatus(uint256 _bankStatus) external onlyOwner {
        bankStatus = _bankStatus;
    }

    /// @dev Bank borrow status allowed or not
    /// @notice check last bit of bankStatus
    function isBorrowAllowed() public view returns (bool) {
        return (bankStatus & 0x01) > 0;
    }

    /// @dev Bank repay status allowed or not
    /// @notice Check second-to-last bit of bankStatus
    function isRepayAllowed() public view returns (bool) {
        return (bankStatus & 0x02) > 0;
    }

    /// @dev Bank borrow status allowed or not
    /// @notice check last bit of bankStatus
    function isLendAllowed() public view returns (bool) {
        return (bankStatus & 0x04) > 0;
    }

    /// @dev Bank borrow status allowed or not
    /// @notice check last bit of bankStatus
    function isWithdrawLendAllowed() public view returns (bool) {
        return (bankStatus & 0x08) > 0;
    }

    /// @dev Trigger interest accrual for the given bank.
    /// @param token The underlying token to trigger the interest accrual.
    function accrue(address token) public override {
        Bank storage bank = banks[token];
        if (!bank.isListed) revert Errors.BANK_NOT_LISTED(token);
        ICErc20(bank.bToken).borrowBalanceCurrent(address(this));
    }

    /// @dev Convenient function to trigger interest accrual for a list of banks.
    /// @param tokens The list of banks to trigger interest accrual.
    function accrueAll(address[] memory tokens) external {
        for (uint256 idx = 0; idx < tokens.length; idx++) {
            accrue(tokens[idx]);
        }
    }

    function _borrowBalanceStored(
        address token
    ) internal view returns (uint256) {
        return ICErc20(banks[token].bToken).borrowBalanceStored(address(this));
    }

    /// @dev Trigger interest accrual and return the current debt balance.
    /// @param positionId The position to query for debt balance.
    function currentPositionDebt(
        uint256 positionId
    )
        external
        override
        poke(positions[positionId].debtToken)
        returns (uint256)
    {
        return getPositionDebt(positionId);
    }

    /// @notice Return the debt of given position considering the debt interest stored.
    /// @dev Should call accrue first to get current debt
    /// @param positionId position id to get debts of
    function getPositionDebt(
        uint256 positionId
    ) public view returns (uint256 debt) {
        Position memory pos = positions[positionId];
        Bank memory bank = banks[pos.debtToken];
        if (pos.debtShare == 0 || bank.totalShare == 0) {
            return 0;
        }
        debt = (pos.debtShare * _borrowBalanceStored(pos.debtToken)).divCeil(
            bank.totalShare
        );
    }

    /// @dev Return bank information for the given token.
    /// @param token The token address to query for bank information.
    function getBankInfo(
        address token
    )
        external
        view
        override
        returns (bool isListed, address bToken, uint256 totalShare)
    {
        Bank memory bank = banks[token];
        return (bank.isListed, bank.bToken, bank.totalShare);
    }

    /// @dev Return position info by given positionId
    function getPositionInfo(
        uint256 positionId
    ) external view override returns (Position memory) {
        return positions[positionId];
    }

    /// @dev Return current position information
    function getCurrentPositionInfo()
        external
        view
        override
        returns (Position memory)
    {
        if (POSITION_ID == _NO_ID) revert Errors.BAD_POSITION(POSITION_ID);
        return positions[POSITION_ID];
    }

    /**
     * @notice Return the USD value of total collateral of the given position
     *         considering yields generated from the collaterals.
     * @param positionId The position ID to query for the collateral value.
     */
    function getPositionValue(
        uint256 positionId
    ) public view override returns (uint256 positionValue) {
        Position memory pos = positions[positionId];
        if (pos.collateralSize == 0) {
            return 0;
        } else {
            if (pos.collToken == address(0))
                revert Errors.BAD_COLLATERAL(positionId);
            uint256 collValue = oracle.getWrappedTokenValue(
                pos.collToken,
                pos.collId,
                pos.collateralSize
            );

            uint rewardsValue;
            (address[] memory tokens, uint256[] memory rewards) = IERC20Wrapper(
                pos.collToken
            ).pendingRewards(pos.collId, pos.collateralSize);
            for (uint256 i; i < tokens.length; i++) {
                rewardsValue += oracle.getTokenValue(tokens[i], rewards[i]);
            }

            return collValue + rewardsValue;
        }
    }

    /// @notice Return the USD value of total debt of the given position considering debt interest stored
    /// @dev Should call accrue first to get current debt
    /// @param positionId The position ID to query for the debt value.
    function getDebtValue(
        uint256 positionId
    ) public view override returns (uint256 debtValue) {
        Position memory pos = positions[positionId];
        uint256 debt = getPositionDebt(positionId);
        debtValue = oracle.getTokenValue(pos.debtToken, debt);
    }

    /// @notice Return the USD value of isolated collateral of given position considering stored lending interest
    /// @dev Should call accrue first to get current debt
    /// @param positionId The position ID to query the isolated collateral value
    function getIsolatedCollateralValue(
        uint256 positionId
    ) public view override returns (uint256 icollValue) {
        Position memory pos = positions[positionId];
        // NOTE: exchangeRateStored has 18 decimals.
        uint256 underlyingAmount;
        if (_isSoftVault(pos.underlyingToken)) {
            underlyingAmount =
                (ICErc20(banks[pos.debtToken].bToken).exchangeRateStored() *
                    pos.underlyingVaultShare) /
                Constants.PRICE_PRECISION;
        } else {
            underlyingAmount = pos.underlyingVaultShare;
        }
        icollValue = oracle.getTokenValue(
            pos.underlyingToken,
            underlyingAmount
        );
    }

    /// @dev Return the risk ratio of given position, higher value, higher risk
    /// @param positionId id of position to check the risk of
    /// @return risk risk ratio, based 1e4
    function getPositionRisk(
        uint256 positionId
    ) public view returns (uint256 risk) {
        uint256 pv = getPositionValue(positionId);
        uint256 ov = getDebtValue(positionId);
        uint256 cv = getIsolatedCollateralValue(positionId);

        if (
            (cv == 0 && pv == 0 && ov == 0) || pv >= ov // Closed position or Overcollateralized position
        ) {
            risk = 0;
        } else if (cv == 0) {
            // Sth bad happened to isolated underlying token
            risk = Constants.DENOMINATOR;
        } else {
            risk = ((ov - pv) * Constants.DENOMINATOR) / cv;
        }
    }

    /// @dev Return the possibility of liquidation
    /// @param positionId id of position to check the liquidation of
    function isLiquidatable(uint256 positionId) public view returns (bool) {
        return
            getPositionRisk(positionId) >=
            banks[positions[positionId].underlyingToken].liqThreshold;
    }

    /// @dev Liquidate a position. Pay debt for its owner and take the collateral.
    /// @param positionId The position ID to liquidate.
    /// @param debtToken The debt token to repay.
    /// @param amountCall The amount to repay when doing transferFrom call.
    function liquidate(
        uint256 positionId,
        address debtToken,
        uint256 amountCall
    ) external override lock poke(debtToken) {
        if (!isRepayAllowed()) revert Errors.REPAY_NOT_ALLOWED();
        if (amountCall == 0) revert Errors.ZERO_AMOUNT();
        if (!isLiquidatable(positionId))
            revert Errors.NOT_LIQUIDATABLE(positionId);

        Position storage pos = positions[positionId];
        Bank memory bank = banks[pos.underlyingToken];
        if (pos.collToken == address(0))
            revert Errors.BAD_COLLATERAL(positionId);

        uint256 oldShare = pos.debtShare;
        (uint256 amountPaid, uint256 share) = _repay(
            positionId,
            debtToken,
            amountCall
        );

        uint256 liqSize = (pos.collateralSize * share) / oldShare;
        uint256 uVaultShare = (pos.underlyingVaultShare * share) / oldShare;

        pos.collateralSize -= liqSize;
        pos.underlyingVaultShare -= uVaultShare;

        // Transfer position (Wrapped LP Tokens) to liquidator
        IERC1155Upgradeable(pos.collToken).safeTransferFrom(
            address(this),
            msg.sender,
            pos.collId,
            liqSize,
            ""
        );
        // Transfer underlying collaterals(vault share tokens) to liquidator
        if (_isSoftVault(pos.underlyingToken)) {
            IERC20Upgradeable(bank.softVault).safeTransfer(
                msg.sender,
                uVaultShare
            );
        } else {
            IERC1155Upgradeable(bank.hardVault).safeTransferFrom(
                address(this),
                msg.sender,
                uint256(uint160(pos.underlyingToken)),
                uVaultShare,
                ""
            );
        }

        emit Liquidate(
            positionId,
            msg.sender,
            debtToken,
            amountPaid,
            share,
            liqSize,
            uVaultShare
        );
    }

    /// @dev Execute the action with the supplied data.
    /// @param positionId The position ID to execute the action, or zero for new position.
    /// @param spell The target spell to invoke the execution.
    /// @param data Extra data to pass to the target for the execution.
    function execute(
        uint256 positionId,
        address spell,
        bytes memory data
    ) external lock onlyEOAEx returns (uint256) {
        if (!whitelistedSpells[spell])
            revert Errors.SPELL_NOT_WHITELISTED(spell);
        if (positionId == 0) {
            positionId = nextPositionId++;
            positions[positionId].owner = msg.sender;
        } else {
            if (positionId >= nextPositionId)
                revert Errors.BAD_POSITION(positionId);
            if (msg.sender != positions[positionId].owner)
                revert Errors.NOT_FROM_OWNER(positionId, msg.sender);
        }
        POSITION_ID = positionId;
        SPELL = spell;

        (bool ok, bytes memory returndata) = SPELL.call(data);
        if (!ok) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("bad cast call");
            }
        }

        if (isLiquidatable(positionId)) revert Errors.INSUFFICIENT_COLLATERAL();

        POSITION_ID = _NO_ID;
        SPELL = _NO_ADDRESS;

        emit Execute(positionId, msg.sender);

        return positionId;
    }

    /**
     * @dev Lend tokens to bank as isolated collateral. Must only be called while under execution.
     * @param token The token to deposit on bank as isolated collateral
     * @param amount The amount of tokens to lend.
     */
    function lend(
        address token,
        uint256 amount
    ) external override inExec poke(token) onlyWhitelistedToken(token) {
        if (!isLendAllowed()) revert Errors.LEND_NOT_ALLOWED();

        Position storage pos = positions[POSITION_ID];
        Bank storage bank = banks[token];
        if (pos.underlyingToken != address(0)) {
            // already have isolated collateral, allow same isolated collateral
            if (pos.underlyingToken != token)
                revert Errors.INCORRECT_UNDERLYING(token);
        } else {
            pos.underlyingToken = token;
        }

        IERC20Upgradeable(token).safeTransferFrom(
            pos.owner,
            address(this),
            amount
        );
        _ensureApprove(token, address(feeManager), amount);
        amount = feeManager.doCutDepositFee(token, amount);

        if (_isSoftVault(token)) {
            _ensureApprove(token, bank.softVault, amount);
            pos.underlyingVaultShare += ISoftVault(bank.softVault).deposit(
                amount
            );
        } else {
            _ensureApprove(token, bank.hardVault, amount);
            pos.underlyingVaultShare += IHardVault(bank.hardVault).deposit(
                token,
                amount
            );
        }

        emit Lend(POSITION_ID, msg.sender, token, amount);
    }

    /**
     * @dev Withdraw isolated collateral tokens lent to bank. Must only be called from spell while under execution.
     * @param token Isolated collateral token address
     * @param shareAmount The amount of vaule share token to withdraw.
     */
    function withdrawLend(
        address token,
        uint256 shareAmount
    ) external override inExec poke(token) {
        if (!isWithdrawLendAllowed()) revert Errors.WITHDRAW_LEND_NOT_ALLOWED();
        Position storage pos = positions[POSITION_ID];
        Bank memory bank = banks[token];
        if (token != pos.underlyingToken) revert Errors.INVALID_UTOKEN(token);
        if (shareAmount == type(uint256).max) {
            shareAmount = pos.underlyingVaultShare;
        }

        uint256 wAmount;
        if (_isSoftVault(token)) {
            _ensureApprove(bank.softVault, bank.softVault, shareAmount);
            wAmount = ISoftVault(bank.softVault).withdraw(shareAmount);
        } else {
            wAmount = IHardVault(bank.hardVault).withdraw(token, shareAmount);
        }

        pos.underlyingVaultShare -= shareAmount;

        _ensureApprove(token, address(feeManager), wAmount);
        wAmount = feeManager.doCutWithdrawFee(token, wAmount);

        IERC20Upgradeable(token).safeTransfer(msg.sender, wAmount);

        emit WithdrawLend(POSITION_ID, msg.sender, token, wAmount);
    }

    /// @dev Borrow tokens from given bank. Must only be called from spell while under execution.
    /// @param token The token to borrow from the bank.
    /// @param amount The amount of tokens to borrow.
    /// @return borrowedAmount Returns the borrowed amount
    function borrow(
        address token,
        uint256 amount
    )
        external
        override
        inExec
        poke(token)
        onlyWhitelistedToken(token)
        returns (uint256 borrowedAmount)
    {
        if (!isBorrowAllowed()) revert Errors.BORROW_NOT_ALLOWED();
        Bank storage bank = banks[token];
        Position storage pos = positions[POSITION_ID];
        if (pos.debtToken != address(0)) {
            // already have some debts, allow same debt token
            if (pos.debtToken != token) revert Errors.INCORRECT_DEBT(token);
        } else {
            pos.debtToken = token;
        }

        uint256 totalShare = bank.totalShare;
        uint256 totalDebt = _borrowBalanceStored(token);
        uint256 share = totalShare == 0
            ? amount
            : (amount * totalShare).divCeil(totalDebt);
        if (share == 0) revert Errors.BORROW_ZERO_SHARE(amount);
        bank.totalShare += share;
        pos.debtShare += share;

        borrowedAmount = _doBorrow(token, amount);
        IERC20Upgradeable(token).safeTransfer(msg.sender, borrowedAmount);

        emit Borrow(POSITION_ID, msg.sender, token, amount, share);
    }

    /// @dev Repay tokens to the bank. Must only be called while under execution.
    /// @param token The token to repay to the bank.
    /// @param amountCall The amount of tokens to repay via transferFrom.
    function repay(
        address token,
        uint256 amountCall
    ) external override inExec poke(token) onlyWhitelistedToken(token) {
        if (!isRepayAllowed()) revert Errors.REPAY_NOT_ALLOWED();
        (uint256 amount, uint256 share) = _repay(
            POSITION_ID,
            token,
            amountCall
        );
        emit Repay(POSITION_ID, msg.sender, token, amount, share);
    }

    /// @dev Perform repay action. Return the amount actually taken and the debt share reduced.
    /// @param positionId The position ID to repay the debt.
    /// @param token The bank token to pay the debt.
    /// @param amountCall The amount to repay by calling transferFrom, or -1 for debt size.
    function _repay(
        uint256 positionId,
        address token,
        uint256 amountCall
    ) internal returns (uint256, uint256) {
        Bank storage bank = banks[token];
        Position storage pos = positions[positionId];
        if (pos.debtToken != token) revert Errors.INCORRECT_DEBT(token);
        uint256 totalShare = bank.totalShare;
        uint256 totalDebt = _borrowBalanceStored(token);
        uint256 oldShare = pos.debtShare;
        uint256 oldDebt = (oldShare * totalDebt).divCeil(totalShare);
        if (amountCall > oldDebt) {
            amountCall = oldDebt;
        }
        amountCall = _doERC20TransferIn(token, amountCall);
        uint256 paid = _doRepay(token, amountCall);
        if (paid > oldDebt) revert Errors.REPAY_EXCEEDS_DEBT(paid, oldDebt); // prevent share overflow attack
        uint256 lessShare = paid == oldDebt
            ? oldShare
            : (paid * totalShare) / totalDebt;
        bank.totalShare -= lessShare;
        pos.debtShare -= lessShare;
        return (paid, lessShare);
    }

    /// @dev Put more collateral for users. Must only be called during execution.
    /// @param collToken The ERC1155 token wrapped for collateral. (Wrapped token of LP)
    /// @param collId The token id to collateral. (Uint256 format of LP address)
    /// @param amountCall The amount of tokens to put via transferFrom.
    function putCollateral(
        address collToken,
        uint256 collId,
        uint256 amountCall
    ) external override inExec onlyWhitelistedERC1155(collToken) {
        Position storage pos = positions[POSITION_ID];
        if (pos.collToken != collToken || pos.collId != collId) {
            if (!oracle.isWrappedTokenSupported(collToken, collId))
                revert Errors.ORACLE_NOT_SUPPORT_WTOKEN(collToken);
            if (pos.collateralSize > 0)
                revert Errors.DIFF_COL_EXIST(pos.collToken);
            pos.collToken = collToken;
            pos.collId = collId;
        }
        uint256 amount = _doERC1155TransferIn(collToken, collId, amountCall);
        pos.collateralSize += amount;
        emit PutCollateral(
            POSITION_ID,
            pos.owner,
            msg.sender,
            collToken,
            collId,
            amount
        );
    }

    /// @dev Take some collateral back. Must only be called during execution.
    /// @param amount The amount of tokens to take back via transfer.
    function takeCollateral(
        uint256 amount
    ) external override inExec returns (uint256) {
        Position storage pos = positions[POSITION_ID];
        if (amount == type(uint256).max) {
            amount = pos.collateralSize;
        }
        pos.collateralSize -= amount;
        IERC1155Upgradeable(pos.collToken).safeTransferFrom(
            address(this),
            msg.sender,
            pos.collId,
            amount,
            ""
        );
        emit TakeCollateral(
            POSITION_ID,
            msg.sender,
            pos.collToken,
            pos.collId,
            amount
        );

        return amount;
    }

    /**
     * @dev Internal function to perform borrow from the bank and return the amount received.
     * @param token The token to perform borrow action.
     * @param amountCall The amount use in the transferFrom call.
     * NOTE: Caller must ensure that bToken interest was already accrued up to this block.
     */
    function _doBorrow(
        address token,
        uint256 amountCall
    ) internal returns (uint256 borrowAmount) {
        address bToken = banks[token].bToken;

        IERC20Upgradeable uToken = IERC20Upgradeable(token);
        uint256 uBalanceBefore = uToken.balanceOf(address(this));
        if (ICErc20(bToken).borrow(amountCall) != 0)
            revert Errors.BORROW_FAILED(amountCall);
        uint256 uBalanceAfter = uToken.balanceOf(address(this));

        borrowAmount = uBalanceAfter - uBalanceBefore;
    }

    /**
     * @dev Internal function to perform repay to the bank and return the amount actually repaid.
     * @param token The token to perform repay action.
     * @param amountCall The amount to use in the repay call.
     * NOTE: Caller must ensure that bToken interest was already accrued up to this block.
     */
    function _doRepay(
        address token,
        uint256 amountCall
    ) internal returns (uint256 repaidAmount) {
        address bToken = banks[token].bToken;
        _ensureApprove(token, bToken, amountCall);
        uint256 beforeDebt = _borrowBalanceStored(token);
        if (ICErc20(bToken).repayBorrow(amountCall) != 0)
            revert Errors.REPAY_FAILED(amountCall);
        uint256 newDebt = _borrowBalanceStored(token);
        repaidAmount = beforeDebt - newDebt;
    }

    /// @dev Internal function to perform ERC20 transfer in and return amount actually received.
    /// @param token The token to perform transferFrom action.
    /// @param amountCall The amount use in the transferFrom call.
    function _doERC20TransferIn(
        address token,
        uint256 amountCall
    ) internal returns (uint256) {
        uint256 balanceBefore = IERC20Upgradeable(token).balanceOf(
            address(this)
        );
        IERC20Upgradeable(token).safeTransferFrom(
            msg.sender,
            address(this),
            amountCall
        );
        uint256 balanceAfter = IERC20Upgradeable(token).balanceOf(
            address(this)
        );
        return balanceAfter - balanceBefore;
    }

    /// @dev Internal function to perform ERC1155 transfer in and return amount actually received.
    /// @param token The token to perform transferFrom action.
    /// @param id The id to perform transferFrom action.
    /// @param amountCall The amount use in the transferFrom call.
    function _doERC1155TransferIn(
        address token,
        uint256 id,
        uint256 amountCall
    ) internal returns (uint256) {
        uint256 balanceBefore = IERC1155Upgradeable(token).balanceOf(
            address(this),
            id
        );
        IERC1155Upgradeable(token).safeTransferFrom(
            msg.sender,
            address(this),
            id,
            amountCall,
            ""
        );
        uint256 balanceAfter = IERC1155Upgradeable(token).balanceOf(
            address(this),
            id
        );
        return balanceAfter - balanceBefore;
    }

    /// @dev Return if the given vault token is soft vault or hard vault
    /// @param token Vault underlying token to check
    /// @return bool True for Soft Vault, False for Hard Vault
    function _isSoftVault(address token) internal view returns (bool) {
        return address(ISoftVault(banks[token].softVault).uToken()) == token;
    }
}
