// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./ISupplyVault.sol";
import "./IBorrowable.sol";

interface ISupplyVaultRouter01 {
    // Deposit underlyingAmount into toBorrowable and then enter vault with token
    function enter(
        ISupplyVault vault,
        uint256 underlyingAmount,
        IBorrowable toBorrowable
    ) external returns (uint256 share);

    // Same but for ETH
    function enterETH(ISupplyVault vault, IBorrowable toBorrowable) external payable returns (uint256 share);

    // Deposit underlyingAmount of vault.underlying() into vault
    function enterWithAlloc(ISupplyVault vault, uint256 underlyingAmount) external returns (uint256 share);

    // Same but for ETH
    function enterWithAllocETH(ISupplyVault vault) external payable returns (uint256 share);

    // Deposit tokenAmount of underlying or borrowable into vault
    function enterWithToken(
        ISupplyVault vault,
        address token,
        uint256 tokenAmount
    ) external returns (uint256 share);

    function leave(ISupplyVault vault, uint256 share) external returns (uint256 underlyingAmount);

    function leaveETH(ISupplyVault vault, uint256 share) external returns (uint256 underlyingAmount);
}