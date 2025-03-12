// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DividenDistributorProxy is ERC1967Proxy {
    /**
     * @dev Initializes the upgradeable proxy with an initial implementation specified by `_logic`.
     *
     * If `_data` is nonempty, it's used as data in a delegate call to `_logic`. This will typically be an encoded
     * function call, and allows initializating the storage of the proxy like a Solidity constructor.
     */
    constructor(address _logic, address _admin, bytes memory _data)
        payable
        ERC1967Proxy(_logic,  _data)
    {
        assert(
            _ADMIN_SLOT ==
                bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
        );
        _changeAdmin(_admin);
    } // solhint-disable-line no-empty-blocks

    function getImplementation()
        external
        view
        returns (address implementation)
    {
        implementation = super._getImplementation();
    }


    function getAdmin()
        external
        view
    returns (address adminAddress)
    {
        adminAddress = super._getAdmin();
    }

    function changeAdmin(address newAdmin) external {
        require(msg.sender == super._getAdmin(), "Caller must be admin");
        super._changeAdmin(newAdmin);
    }
}
