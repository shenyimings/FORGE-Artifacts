// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVault {
    // --- Events ---
    event WantUpdated(address _want);
    event StrategyUpdated(address _strategy);
    event StrategyProposed(address _strategy);
    event Deposited(address indexed _user, uint256 _amount);
    event Withdrawn(address indexed _user, uint256 _shares);

    // --- Functions ---
    function want() external view returns (IERC20);

    function balance() external view returns (uint256);

    function available() external view returns (uint256);

    function getPricePerFullShare() external view returns (uint256);

    function depositAll() external returns (uint256);

    function deposit(uint256 _amount) external returns (uint256);

    function earn() external;

    function withdrawAll() external returns (uint256);

    function withdraw(uint256 _shares) external returns (uint256);

    function proposeStrat(address _implementation) external;

    function upgradeStrat() external;

    function inCaseTokensGetStuck(address _token) external;
}
