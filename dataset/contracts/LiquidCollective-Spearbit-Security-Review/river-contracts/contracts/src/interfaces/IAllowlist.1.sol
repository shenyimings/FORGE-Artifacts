//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IAllowlistV1 {
    event ChangedAllowlistStatuses(address[] indexed accounts, uint256[] statuses);

    error InvalidAlloweeCount();
    error Denied(address _account);
    error Unauthorized(address _account);
    error MismatchedAlloweeAndStatusCount();

    function initAllowlistV1(address _admin, address _allower) external;
    function setAllower(address _newAllowerAddress) external;
    function getAllower() external view returns (address);
    function allow(address[] calldata _accounts, uint256[] calldata _statuses) external;
    function onlyAllowed(address _account, uint256 _mask) external view;
    function isAllowed(address _account, uint256 _mask) external view returns (bool);
    function isDenied(address _account) external view returns (bool);
    function hasPermission(address _account, uint256 _mask) external view returns (bool);
    function getPermissions(address _account) external view returns (uint256);
}
