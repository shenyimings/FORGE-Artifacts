// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract AdminRole {
    using EnumerableSet for EnumerableSet.AddressSet;
    /// @dev 管理员set
    EnumerableSet.AddressSet private _admins;

    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);

    /**
     * @dev 构造函数
     */
    constructor() {
        _addAdmin(msg.sender);
    }

    /**
     * @dev 修改器:只能通过管理员调用
     */
    modifier onlyAdmin() {
        require(
            isAdmin(msg.sender), "AdminRole: caller does not have the Admin role"
        );
        _;
    }

    /**
     * @dev 判断是否是管理员
     * @param account 帐号地址
     * @return 是否是管理员
     */
    function isAdmin(address account) public view returns (bool) {
        return _admins.contains(account);
    }

    /**
     * @dev 返回所有管理员
     * @return admins 管理员数组
     */
    function allAdmins() public view returns (address[] memory admins) {
        admins = new address[](_admins.length());
        for (uint256 i = 0; i < _admins.length(); i++) {
            admins[i] = _admins.at(i);
        }
    }

    /**
     * @dev 添加管理员
     * @param account 帐号地址
     */
    function addAdmin(address account) public onlyAdmin {
        _addAdmin(account);
    }

    /**
     * @dev 移除管理员
     * @param account 帐号地址
     */
    function removeAdmin(address account) public onlyAdmin {
        _removeAdmin(account);
    }

    /**
     * @dev 撤销管理员
     */
    function renounceAdmin() public {
        _removeAdmin(msg.sender);
    }

    /**
     * @dev 私有添加管理员
     * @param account 帐号地址
     */
    function _addAdmin(address account) internal {
        _admins.add(account);
        emit AdminAdded(account);
    }

    /**
     * @dev 私有移除管理员
     * @param account 帐号地址
     */
    function _removeAdmin(address account) internal {
        _admins.remove(account);
        emit AdminRemoved(account);
    }
}
