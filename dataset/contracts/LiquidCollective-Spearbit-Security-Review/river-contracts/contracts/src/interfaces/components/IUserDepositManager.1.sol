//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IUserDepositManagerV1 {
    event UserDeposit(address indexed depositor, address indexed recipient, uint256 amount);

    error EmptyDeposit();
    error EmptyDonation();

    function getPendingEth() external view returns (uint256);
    function deposit() external payable;
    function depositAndTransfer(address _recipient) external payable;
    receive() external payable;
    fallback() external payable;
}
