// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface IFARM {
    function HARD_CAP() external view returns (uint256);

    function addMinter(address _minter) external;

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function cap() external view returns (uint256);

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

    function governance() external view returns (address);

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    function isMinter(address account) external view returns (bool);

    function mint(address account, uint256 amount) external returns (bool);

    function name() external view returns (string memory);

    function renounceMinter() external;

    function setStorage(address _store) external;

    function store() external view returns (address);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}
