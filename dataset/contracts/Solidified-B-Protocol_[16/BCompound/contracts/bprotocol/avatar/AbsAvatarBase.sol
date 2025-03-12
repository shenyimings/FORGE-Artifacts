pragma solidity 0.5.16;

import { ICToken } from "../interfaces/CTokenInterfaces.sol";
import { IComptroller } from "../interfaces/IComptroller.sol";
import { IRegistry } from "../interfaces/IRegistry.sol";
import { IScore } from "../interfaces/IScore.sol";
import { Exponential } from "../lib/Exponential.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICToken, ICErc20, ICEther } from "../interfaces/CTokenInterfaces.sol";

contract AbsAvatarBase is Exponential {
    using SafeERC20 for IERC20;

    IRegistry public registry;
    bool public quit;

    /* Storage for topup details */
    // Topped up cToken
    ICToken public toppedUpCToken;
    // Topped up amount of tokens
    uint256 public toppedUpAmount;
    // Remaining max amount available for liquidation
    uint256 public remainingLiquidationAmount;
    // Liquidation cToken
    ICToken public liquidationCToken;

    modifier onlyAvatarOwner() {
        require(msg.sender == registry.ownerOf(address(this)), "sender-is-not-owner");
        _;
    }

    modifier onlyPool() {
        require(msg.sender == pool(), "only-pool-is-authorized");
        _;
    }

    modifier onlyBComptroller() {
        require(msg.sender == registry.bComptroller(), "only-BComptroller-is-authorized");
        _;
    }

    modifier postPoolOp(bool debtIncrease) {
        _;
        _reevaluate(debtIncrease);
    }

    function _initAvatarBase(address _registry) internal {
        require(registry == IRegistry(0x0), "avatar-already-init");
        registry = IRegistry(_registry);
    }

    /**
     * @dev Hard check to ensure untop is allowed and then reset remaining liquidation amount
     */
    function _hardReevaluate() internal {
        // Check: must allowed untop
        require(canUntop(), "cannot-untop");
        // Reset it to force re-calculation
        remainingLiquidationAmount = 0;
    }

    /**
     * @dev Soft check and reset remaining liquidation amount
     */
    function _softReevaluate() private {
        if(isPartiallyLiquidated()) {
            _hardReevaluate();
        }
    }

    function _reevaluate(bool debtIncrease) private {
        if(debtIncrease) {
            _hardReevaluate();
        } else {
            _softReevaluate();
        }
    }

    function _isCEther(ICToken cToken) internal view returns (bool) {
        return address(cToken) == registry.cEther();
    }

    function _score() internal view returns (IScore) {
        return IScore(registry.score());
    }

    function toInt256(uint256 value) internal pure returns (int256) {
        int256 result = int256(value);
        require(result >= 0, "Cast from uint to int failed");
        return result;
    }

    function isPartiallyLiquidated() public view returns (bool) {
        return remainingLiquidationAmount > 0;
    }

    function isToppedUp() public view returns (bool) {
        return toppedUpAmount > 0;
    }

    /**
     * @dev Checks if this Avatar can untop the amount.
     * @return `true` if allowed to borrow, `false` otherwise.
     */
    function canUntop() public returns (bool) {
        // When not topped up, just return true
        if(!isToppedUp()) return true;
        IComptroller comptroller = IComptroller(registry.comptroller());
        bool result = comptroller.borrowAllowed(address(toppedUpCToken), address(this), toppedUpAmount) == 0;
        return result;
    }

    function pool() public view returns (address payable) {
        return address(uint160(registry.pool()));
    }

    /**
     * @dev Returns the status if this Avatar's debt can be liquidated
     * @return `true` when this Avatar can be liquidated, `false` otherwise
     */
    function canLiquidate() public returns (bool) {
        bool result = isToppedUp() && (remainingLiquidationAmount > 0) || (!canUntop());

        return result;
    }

    /**
     * @dev Topup this avatar by repaying borrowings with ETH
     */
    function topup() external payable onlyPool {
        require(! quit, "Cushion: user-quit-B");

        address cEtherAddr = registry.cEther();
        // when already topped
        bool _isToppedUp = isToppedUp();
        if(_isToppedUp) {
            require(address(toppedUpCToken) == cEtherAddr, "Cushion: already-topped-with-other-cToken");
        }

        // 2. Repay borrows from Pool to topup
        ICEther cEther = ICEther(cEtherAddr);
        cEther.repayBorrow.value(msg.value)();

        // 3. Store Topped-up details
        if(! _isToppedUp) toppedUpCToken = cEther;
        toppedUpAmount = add_(toppedUpAmount, msg.value);
    }

    /**
     * @dev Topup the borrowed position of this Avatar by repaying borrows from the pool
     * @notice Only Pool contract allowed to call the topup.
     * @param cToken CToken address to use to RepayBorrows
     * @param topupAmount Amount of tokens to Topup
     */
    function topup(ICErc20 cToken, uint256 topupAmount) external onlyPool {
        require(! quit, "Cushion: user-quit-B");

        // when already topped
        bool _isToppedUp = isToppedUp();
        if(_isToppedUp) {
            require(toppedUpCToken == cToken, "Cushion: already-topped-with-other-cToken");
        }

        // 1. Transfer funds from the Pool contract
        IERC20 underlying = cToken.underlying();
        underlying.safeTransferFrom(pool(), address(this), topupAmount);
        underlying.safeApprove(address(cToken), topupAmount);

        // 2. Repay borrows from Pool to topup
        require(cToken.repayBorrow(topupAmount) == 0, "RepayBorrow-failed");

        // 3. Store Topped-up details
        if(! _isToppedUp) toppedUpCToken = cToken;
        toppedUpAmount = add_(toppedUpAmount, topupAmount);
    }

    function untop(uint amount) external onlyPool {
        _untop(amount, amount);
    }

    /**
     * @dev Untop the borrowed position of this Avatar by borrowing from Compound and transferring
     *      it to the pool.
     * @notice Only Pool contract allowed to call the untop.
     * @return `true` if success, `false` otherwise.
     */
    function _untop(uint amount, uint amountToBorrow) internal {
        // when already untopped
        if(!isToppedUp()) return;

        // 1. Udpdate storage for toppedUp details
        require(toppedUpAmount >= amount, "Cushion: amount >= toppedUpAmount");
        toppedUpAmount = sub_(toppedUpAmount, amount);
        if((toppedUpAmount == 0) && (remainingLiquidationAmount > 0)) remainingLiquidationAmount = 0;

        // 2. Borrow from Compound and send tokens to Pool
        if(amountToBorrow > 0 )
            require(toppedUpCToken.borrow(amountToBorrow) == 0, "Cushion: borrow-failed");

        if(address(toppedUpCToken) == registry.cEther()) {
            // 3. Send borrowed ETH to Pool contract
            // Sending ETH to Pool using `.send()` to avoid DoS attack
            bool success = pool().send(amount);
            success; // shh: Not checking return value to avoid DoS attack
        } else {
            // 3. Transfer borrowed amount to Pool contract
            IERC20 underlying = toppedUpCToken.underlying();
            underlying.safeTransfer(pool(), amount);
        }
    }

    function _untop() internal {
        // when already untopped
        if(!isToppedUp()) return;
        _untop(toppedUpAmount, toppedUpAmount);
    }

    function _untopBeforeRepay(ICToken cToken, uint256 repayAmount) internal returns (uint256 amtToRepayOnCompound) {
        if(toppedUpAmount > 0 && cToken == toppedUpCToken) {
            // consume debt from cushion first
            uint256 amtToUntopFromB = repayAmount >= toppedUpAmount ? toppedUpAmount : repayAmount;
            _untop(toppedUpAmount, sub_(toppedUpAmount, amtToUntopFromB));
            amtToRepayOnCompound = sub_(repayAmount, amtToUntopFromB);
        } else {
            amtToRepayOnCompound = repayAmount;
        }
    }

    function _doLiquidateBorrow(
        ICToken debtCToken,
        uint256 underlyingAmtToLiquidate,
        uint256 amtToDeductFromTopup,
        ICToken collCToken
    )
        internal
        returns (uint256)
    {
        address payable poolContract = pool();
        require(poolContract == msg.sender, "liquidateBorrow:-only-pool-can-liquidate");

        // 1. Is toppedUp OR partially liquidated
        bool partiallyLiquidated = isPartiallyLiquidated();
        require(isToppedUp() || partiallyLiquidated, "cannot-perform-liquidateBorrow");

        if(partiallyLiquidated) {
            require(debtCToken == liquidationCToken, "debtCToken-not-equal-to-liquidationCToken");
        } else {
            require(debtCToken == toppedUpCToken, "debtCToken-not-equal-to-toppedUpCToken");
            liquidationCToken = debtCToken;
        }

        if(!partiallyLiquidated) {
            remainingLiquidationAmount = getMaxLiquidationAmount(debtCToken);
        }

        // 2. `underlayingAmtToLiquidate` is under limit
        require(underlyingAmtToLiquidate <= remainingLiquidationAmount, "liquidateBorrow:-amountToLiquidate-is-too-big");

        // 3. Liquidator perform repayBorrow
        require(underlyingAmtToLiquidate >= amtToDeductFromTopup, "liquidateBorrow:-amtToDeductFromTopup>underlyingAmtToLiquidate");
        uint256 amtToRepayOnCompound = sub_(underlyingAmtToLiquidate, amtToDeductFromTopup);
        
        if(amtToRepayOnCompound > 0) {
            bool isCEtherDebt = _isCEther(debtCToken);
            if(isCEtherDebt) {
                // CEther
                require(msg.value == amtToRepayOnCompound, "insuffecient-ETH-sent");
                ICEther cEther = ICEther(registry.cEther());
                cEther.repayBorrow.value(amtToRepayOnCompound)();
            } else {
                // CErc20
                // take tokens from pool contract
                IERC20 underlying = toppedUpCToken.underlying();
                underlying.safeTransferFrom(poolContract, address(this), amtToRepayOnCompound);
                underlying.safeApprove(address(debtCToken), amtToRepayOnCompound);
                require(ICErc20(address(debtCToken)).repayBorrow(amtToRepayOnCompound) == 0, "liquidateBorrow:-repayBorrow-failed");
            }
        }

        require(toppedUpAmount >= amtToDeductFromTopup, "liquidateBorrow:-amtToDeductFromTopup>toppedUpAmount");
        toppedUpAmount = sub_(toppedUpAmount, amtToDeductFromTopup);

        // 4.1 Update remaining liquidation amount
        remainingLiquidationAmount = sub_(remainingLiquidationAmount, underlyingAmtToLiquidate);

        // 5. Calculate premium and transfer to Liquidator
        IComptroller comptroller = IComptroller(registry.comptroller());
        (uint err, uint seizeTokens) = comptroller.liquidateCalculateSeizeTokens(
            address(debtCToken),
            address(collCToken),
            underlyingAmtToLiquidate
        );
        require(err == 0, "error-in-liquidateCalculateSeizeTokens");

        // 6. Transfer permiumAmount to liquidator
        require(collCToken.transfer(poolContract, seizeTokens), "collateral-cToken-transfer-failed");

        return seizeTokens;
    }

    function getMaxLiquidationAmount(ICToken debtCToken) public returns (uint256) {
        if(isPartiallyLiquidated()) return remainingLiquidationAmount;

        uint256 avatarDebt = debtCToken.borrowBalanceCurrent(address(this));
        // `toppedUpAmount` is also called poolDebt;
        uint256 totalDebt = add_(avatarDebt, toppedUpAmount);
        // When First time liquidation is performed after topup
        // maxLiquidationAmount = closeFactorMantissa * totalDedt / 1e18;
        IComptroller comptroller = IComptroller(registry.comptroller());
        return mulTrucate(comptroller.closeFactorMantissa(), totalDebt);
    }

    function splitAmountToLiquidate(
        uint256 underlyingAmtToLiquidate,
        uint256 maxLiquidationAmount
    )
        public view returns (uint256 amtToDeductFromTopup, uint256 amtToRepayOnCompound)
    {
        // underlyingAmtToLiqScalar = underlyingAmtToLiquidate * 1e18
        (MathError mErr, Exp memory result) = mulScalar(Exp({mantissa: underlyingAmtToLiquidate}), expScale);
        require(mErr == MathError.NO_ERROR, "underlyingAmtToLiqScalar failed");
        uint underlyingAmtToLiqScalar = result.mantissa;

        // percent = underlyingAmtToLiqScalar / maxLiquidationAmount
        uint256 percentInScale = div_(underlyingAmtToLiqScalar, maxLiquidationAmount);

        // amtToDeductFromTopup = toppedUpAmount * percentInScale / 1e18
        amtToDeductFromTopup = mulTrucate(toppedUpAmount, percentInScale);

        // amtToRepayOnCompound = underlyingAmtToLiquidate - amtToDeductFromTopup
        amtToRepayOnCompound = sub_(underlyingAmtToLiquidate, amtToDeductFromTopup);
    }

    /**
     * @dev Off-chain function to calculate `amtToDeductFromTopup` and `amtToRepayOnCompound`
     * @notice function is non-view but no-harm as CToken.borrowBalanceCurrent() only updates accured interest
     */
    function calcAmountToLiquidate(
        ICToken debtCToken,
        uint256 underlyingAmtToLiquidate
    )
        external returns (uint256 amtToDeductFromTopup, uint256 amtToRepayOnCompound)
    {
        uint256 amountToLiquidate = remainingLiquidationAmount;
        if(! isPartiallyLiquidated()) {
            amountToLiquidate = getMaxLiquidationAmount(debtCToken);
        }
        (amtToDeductFromTopup, amtToRepayOnCompound) = splitAmountToLiquidate(underlyingAmtToLiquidate, amountToLiquidate);
    }

    function quitB() external onlyAvatarOwner() {
        quit = true;
        _hardReevaluate();
    }
}
