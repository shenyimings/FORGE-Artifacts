// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.16;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import '../interfaces/IArkenSmithyPool.sol';
import '../interfaces/IArkenSmithy.sol';

/// @notice This is an extensible contract for every Arken product which needs to withdraw ARKEN from SMITHY.
abstract contract ArkenSmithyPool is
    Ownable,
    ReentrancyGuard,
    IArkenSmithyPool
{
    // Modified from PancakeSwap code:
    // MasterChef: https://github.com/pancakeswap/pancake-smart-contracts/blob/master/projects/farms-pools/contracts/MasterChef.sol
    // MasterChefV2: https://bscscan.com/address/0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652#code

    using SafeERC20 for IERC20;

    /// @notice Arken minter contract
    IArkenSmithy public immutable ARKEN_SMITHY;

    /// @notice The pool id on ArkenSmithy
    uint256 public immutable SMITHY_PID;

    /// @notice The ARKEN Token!
    IERC20 public immutable ARKEN;

    event InitPoolId(uint256 smithyPid);
    event EmergencyAdminWithdraw(address indexed to, uint256 amount);

    constructor(
        IArkenSmithy _ARKEN_SMITHY,
        IERC20 _ARKEN,
        uint256 _SMITHY_PID
    ) {
        ARKEN_SMITHY = _ARKEN_SMITHY;
        ARKEN = _ARKEN;
        SMITHY_PID = _SMITHY_PID;
    }

    /// @notice Calculate ARKEN per block for this contract's pool on SMITHY.
    function arkenPerBlock() public view returns (uint256 amount) {
        amount = ARKEN_SMITHY.arkenPerBlock(SMITHY_PID);
    }

    function getReward(uint256 fromBlock, uint256 toBlock)
        public
        view
        returns (uint256 amount)
    {
        amount = ARKEN_SMITHY.getReward(SMITHY_PID, fromBlock, toBlock);
    }

    /// @notice Calculate pending ARKEN for this contract's pool on SMITHY.
    function totalPendingArken() public view returns (uint256 amount) {
        amount = ARKEN_SMITHY.pendingArken(SMITHY_PID);
    }

    /// @notice Withdraw all pending ARKEN in !EXTREME SITUATION!
    ///     The owner of this contract should be Timelock with Multi-sig as an executor.
    ///     So this function will be protected from any malicious action from owner's end.
    /// @param _to The address to transfer ARKEN to.
    function emergencyAdminWithdraw(address _to) external onlyOwner {
        uint256 amount = totalPendingArken();
        ARKEN_SMITHY.withdraw(_to, SMITHY_PID, amount);
        emit EmergencyAdminWithdraw(_to, amount);
    }

    /// @notice Withdraw ARKEN to certain address.
    /// @param _to The address to transfer ARKEN to.
    /// @param _amount The amount of ARKEN to transfer. This assumes that the caller calculated the correct amount for this recipient.
    function _withdrawFromSmithy(address _to, uint256 _amount) internal {
        ARKEN_SMITHY.withdraw(_to, SMITHY_PID, _amount);
    }
}
