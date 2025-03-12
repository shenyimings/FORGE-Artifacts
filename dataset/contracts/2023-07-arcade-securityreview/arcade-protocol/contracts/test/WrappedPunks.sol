// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../external/interfaces/IPunks.sol";
import "./UserProxy.sol";

contract WrappedPunk is ERC721 {
    event ProxyRegistered(address user, address proxy);

    // Instance of cryptopunk smart contract
    IPunks private _punkContract;

    // Mapping from user address to proxy address
    mapping(address => address) private _proxies;

    /**
     * @dev Initializes the contract settings
     */
    constructor(address punkContract_) ERC721("Wrapped Cryptopunks", "WPUNKS") {
        _punkContract = IPunks(punkContract_);
    }

    /**
     * @dev Gets address of cryptopunk smart contract
     */
    function punkContract() public view returns (address) {
        return address(_punkContract);
    }

    /**
     * @dev Registers proxy
     */
    function registerProxy() public {
        address sender = _msgSender();

        require(_proxies[sender] == address(0), "PunkWrapper: caller has registered the proxy");

        address proxy = address(new UserProxy());

        _proxies[sender] = proxy;

        emit ProxyRegistered(sender, proxy);
    }

    /**
     * @dev Gets proxy address
     */
    function proxyInfo(address user) public view returns (address) {
        return _proxies[user];
    }

    /**
     * @dev Mints a wrapped punk
     */
    function mint(uint256 punkIndex) public {
        address sender = _msgSender();

        UserProxy proxy = UserProxy(_proxies[sender]);

        require(proxy.transfer(address(_punkContract), punkIndex), "PunkWrapper: transfer fail");

        _mint(sender, punkIndex);
    }

    /**
     * @dev Burns a specific wrapped punk
     */
    function burn(uint256 punkIndex) public {
        address sender = _msgSender();

        require(_isApprovedOrOwner(sender, punkIndex), "PunkWrapper: caller is not owner nor approved");

        _burn(punkIndex);

        // Transfers ownership of punk on original cryptopunk smart contract to caller
        _punkContract.transferPunk(sender, punkIndex);
    }
}
