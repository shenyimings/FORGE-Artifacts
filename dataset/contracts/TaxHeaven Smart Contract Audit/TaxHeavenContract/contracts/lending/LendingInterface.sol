// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.1;

interface LendingInterface {
    function depositEth() external payable;

    function depositErc20(address tokenAddress, uint256 amount) external;

    function borrow(address tokenAddress, uint256 amount) external;

    function withdraw(address tokenAddress, uint256 amount) external;

    function repayEth() external payable;

    function repayErc20(address tokenAddress, uint256 amount) external;

    function forceLiquidate(address token, address account) external;

    function getStakingAddress() external view returns (address);

    function getTaxTokenAddress() external view returns (address);

    function getInterest() external view returns (uint256);

    function getTvl(address tokenAddress) external view returns (uint256);

    function getTotalLending(address tokenAddress) external view returns (uint256);

    function getTotalBorrowing(address tokenAddress) external view returns (uint256);

    function getTokenInfo(address tokenAddress)
        external
        view
        returns (uint256 totalLendAmount, uint256 totalBorrowAmount);

    function getLenderAccount(address tokenAddress, address userAddress)
        external
        view
        returns (uint256);

    function getBorrowerAccount(address tokenAddress, address userAddress)
        external
        view
        returns (uint256);

    function getRemainingCredit(address tokenAddress, address userAddress)
        external
        view
        returns (uint256);

    function getAccountInfo(address tokenAddress, address userAddress)
        external
        view
        returns (
            uint256 lendAccount,
            uint256 borrowAccount,
            uint256 remainingCredit
        );
}
