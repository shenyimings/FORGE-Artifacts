// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC4907a {

    event ApproveSetter(address indexed owner, address setter, uint256 tokenId);

    event ApproveSetterForAll(address indexed owner, address setter, bool approved);

    /**
     * @dev Returns if the `setter` is allowed to set user.
     *
     * See {setApprove}
     */
    function isSetterApproved(uint256 tokenId) external view returns(address);

    function isSetterApprovedForAll(address owner, address setter) external view returns(bool);

    /**
     * @dev Set approval for setter
     */
    function approveSetter(address setter, uint256 tokenId) external;

    function approveSetterForAll(address setter, bool approved) external;
}