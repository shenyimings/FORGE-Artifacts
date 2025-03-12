pragma solidity ^0.7.5;

interface IGyro {
    function burnFrom(address account_, uint256 amount_) external;

    function circulatingSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
