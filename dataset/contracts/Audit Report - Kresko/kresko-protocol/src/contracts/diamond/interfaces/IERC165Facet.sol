// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;
import {DiamondEvent} from "../../libs/Events.sol";

interface IERC165Facet {
    /**
     * @notice Query if a contract implements an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @dev Interface identification is specified in ERC-165. This function
     *  uses less than 30,000 gas.
     * @return `true` if the contract implements `interfaceID` and
     *  `interfaceID` is not 0xffffffff, `false` otherwise
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    /**
     * @notice set or unset ERC165 using DiamondStorage.supportedInterfaces
     * @param interfaceIds list of interface id to set as supported
     * @param interfaceIdsToRemove list of interface id to unset as supported.
     * Technically, you can remove support of ERC165 by having the IERC165 id itself being part of that array.
     */
    function setERC165(bytes4[] calldata interfaceIds, bytes4[] calldata interfaceIdsToRemove) external;
}
