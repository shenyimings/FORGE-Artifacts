// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/EmissionMath.sol";
import "./interfaces/IVGlobalMinter.sol";
import "./VVestingWallet.sol";
import "./Vrsw.sol";

/**
 * @title vGlobalMinter
 * @dev This contract is responsible for minting and distributing VRSW tokens.
 */
contract VGlobalMinter is IVGlobalMinter, Ownable {
    // list of all vesting wallets that were created by the minter
    address[] public vestingWallets;

    // VRSW algorithmic distribution is divided into epochs

    // the timestamp of the current epoch start
    uint32 public startEpochTime;

    // current epoch duration (in seconds)
    uint32 public epochDuration;

    // the time (in seconds) before the next epoch to transfer the necessary
    // amount of VRSW tokens for the next epoch to distribute
    uint32 public epochPreparationTime;

    // the next epoch duration
    // if the value is zero then the next epoch duration is the same as the current
    // epoch duration
    uint32 public nextEpochDuration;

    // the next epoch preparation time
    // if the value is zero then the next epoch preparation time is the same as
    // the current epoch preparation time
    uint32 public nextEpochPreparationTime;

    // timestamp of VRSW emission start
    uint32 public immutable emissionStartTs;

    // amount of VRSW tokens locked for algorithmic emission
    uint256 public lockedBalance;

    // VRSW token
    Vrsw public immutable vrsw;

    /**
     * @dev Constructor function. All VRSW tokens must be transferred here right
     * after contract creation.
     * @param _emissionStartTs Timestamp of the start of emission
     * @param _vrsw Address of VRSW token
     */
    constructor(uint32 _emissionStartTs, address _vrsw) {
        require(_vrsw != address(0), "zero address");
        emissionStartTs = _emissionStartTs;
        lockedBalance = 5e8 * 1e18;
        epochDuration = 4 weeks;
        epochPreparationTime = 1 weeks;
        startEpochTime = _emissionStartTs - epochDuration;
        vrsw = Vrsw(_vrsw);
    }

    /// @inheritdoc IVGlobalMinter
    function newVesting(
        address beneficiary,
        uint32 startTs,
        uint32 duration,
        uint256 amount
    ) external override onlyOwner returns (address vestingWallet) {
        require(amount <= unlockedBalance(), "not enough unlocked tokens");
        require(amount > 0, "amount must be positive");
        vestingWallet = address(
            new vVestingWallet(
                beneficiary,
                address(vrsw),
                uint64(startTs),
                uint64(duration)
            )
        );
        vestingWallets.push(vestingWallet);
        SafeERC20.safeTransfer(IERC20(vrsw), vestingWallet, amount);
        emit NewVesting(vestingWallet, beneficiary, startTs, duration);
    }

    /// @inheritdoc IVGlobalMinter
    function arbitraryTransfer(
        address to,
        uint256 amount
    ) external override onlyOwner {
        require(amount <= unlockedBalance(), "not enough unlocked tokens");
        require(amount > 0, "amount must be positive");
        SafeERC20.safeTransfer(IERC20(vrsw), to, amount);
    }

    /// @inheritdoc IVGlobalMinter
    function nextEpochTransfer() external override onlyOwner {
        uint256 currentEpochEnd = startEpochTime + epochDuration;
        _epochTransition();
        // now startEpochTime points to the next epoch start
        require(
            block.timestamp + epochPreparationTime >= startEpochTime,
            "Too early"
        );
        uint256 amountToTransfer = EmissionMath.calculateAlgorithmicEmission(
            currentEpochEnd - emissionStartTs,
            startEpochTime + epochDuration - emissionStartTs
        );
        lockedBalance -= amountToTransfer;
        SafeERC20.safeTransfer(IERC20(vrsw), msg.sender, amountToTransfer);
    }

    /// @inheritdoc IVGlobalMinter
    function setEpochParams(
        uint32 _epochDuration,
        uint32 _epochPreparationTime
    ) external override onlyOwner {
        require(
            _epochPreparationTime > 0 && _epochDuration > 0,
            "must be greater than zero"
        );
        require(
            _epochPreparationTime < _epochDuration,
            "preparationTime >= epochDuration"
        );
        (nextEpochPreparationTime, nextEpochDuration) = (
            _epochPreparationTime,
            _epochDuration
        );
    }

    /// @inheritdoc IVGlobalMinter
    function getAllVestingWallets()
        external
        view
        override
        returns (address[] memory)
    {
        return vestingWallets;
    }

    /**
     * @dev Calculates the number of unlocked VRSW tokens.
     * @return Amount of unlocked VRSW tokens.
     */
    function unlockedBalance() public view returns (uint256) {
        return vrsw.balanceOf(address(this)) - lockedBalance;
    }

    /**
     * @dev Transfers through multiple epochs right to the epoch, which
     * start is after block.timestamp
     */
    function _epochTransition() private {
        uint256 _startEpochTime = startEpochTime + epochDuration;
        if (nextEpochDuration > 0) {
            epochDuration = nextEpochDuration;
            nextEpochDuration = 0;
        }
        if (nextEpochPreparationTime > 0) {
            epochPreparationTime = nextEpochPreparationTime;
            nextEpochPreparationTime = 0;
        }
        uint256 _epochDuration = epochDuration;
        while (block.timestamp >= _startEpochTime) {
            _startEpochTime += _epochDuration;
        }
        startEpochTime = uint32(_startEpochTime);
    }
}
