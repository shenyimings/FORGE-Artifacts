// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract TortleTreasury is Ownable {
    using SafeERC20 for IERC20;
    using LowGasSafeMath for uint256;

    address public accountant;

    struct Withdrawal {
        uint256 amount;
        address token;
        uint256 time;
        bool reviewed;
    }

    uint256 counter = 0;

    mapping(uint256 => Withdrawal) public withdrawals;

    function viewWithdrawal(uint256 index)
        public
        view
        returns (
            uint256,
            address,
            uint256,
            bool
        )
    {
        Withdrawal memory receipt = withdrawals[index];
        return (receipt.amount, receipt.token, receipt.time, receipt.reviewed);
    }

    function markReviewed(uint256 index) public returns (bool) {
        require(msg.sender == accountant, 'not authorized');
        withdrawals[index].reviewed = true;
        return true;
    }

    function withdrawTokens(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        withdrawals[counter] = Withdrawal(_amount, _token, block.timestamp, false);
        counter++;
        IERC20(_token).safeTransfer(_to, _amount);
    }

    function withdrawFTM(address payable _to, uint256 _amount) external onlyOwner {
        withdrawals[counter] = Withdrawal(_amount, address(0), block.timestamp, false);
        counter++;
        _to.transfer(_amount);
    }

    function setAccountant(address _addr) public onlyOwner returns (bool) {
        accountant = _addr;
        return true;
    }

    receive() external payable {}
}
