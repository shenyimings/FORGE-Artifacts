// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "../Token.sol";
import "./Factory.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title TokenProxyFactory
 * @author malteish
 * @notice Use this contract to create ERC1967 proxies for Token contracts
 */
contract TokenProxyFactory is Factory {
    event NewProxy(address proxy);

    constructor(address _implementation) Factory(_implementation) {}

    /**
     * create a new proxy and initialize it
     * @param _rawSalt value that influences the address of the proxy, but not the initialization
     * @param _trustedForwarder trustedForwarder can not be changed, but is checked for security
     * @param _feeSettings address of the FeeSettings contract to use in the new token
     * @param _admin default-admin of the new token
     * @param _allowList AllowList of the new token
     * @param _requirements Which requirements to use in the new token
     * @param _name token name (e.g. "Test Token")
     * @param _symbol token symbol (e.g. "TST")
     * @return address of the new proxy
     */
    function createTokenProxy(
        bytes32 _rawSalt,
        address _trustedForwarder,
        IFeeSettingsV2 _feeSettings,
        address _admin,
        AllowList _allowList,
        uint256 _requirements,
        string memory _name,
        string memory _symbol
    ) external returns (address) {
        bytes32 salt = _getSalt(
            _rawSalt,
            _trustedForwarder,
            _feeSettings,
            _admin,
            _allowList,
            _requirements,
            _name,
            _symbol
        );
        address proxyAddress = Create2.deploy(0, salt, getBytecode());
        ERC1967Proxy proxy = ERC1967Proxy(payable(proxyAddress));
        Token cloneToken = Token(address(proxy));
        require(cloneToken.isTrustedForwarder(_trustedForwarder), "TokenProxyFactory: Unexpected trustedForwarder");
        cloneToken.initialize(_feeSettings, _admin, _allowList, _requirements, _name, _symbol);
        emit NewProxy(address(proxy));
        return address(proxy);
    }

    /**
     * Calculate which address a token would have if it was created with these parameters.
     * @param _rawSalt value that influences the address of the proxy, but not the initialization
     * @param _trustedForwarder trustedForwarder can not be changed, but is checked for security
     * @param _feeSettings address of the FeeSettings contract to use in the new token
     * @param _admin default-admin of the new token
     * @param _allowList AllowList of the new token
     * @param _requirements Which requirements to use in the new token
     * @param _name token name (e.g. "Test Token")
     * @param _symbol token symbol (e.g. "TST")
     * @return address of the token that would be created
     */
    function predictProxyAddress(
        bytes32 _rawSalt,
        address _trustedForwarder,
        IFeeSettingsV2 _feeSettings,
        address _admin,
        AllowList _allowList,
        uint256 _requirements,
        string memory _name,
        string memory _symbol
    ) external view returns (address) {
        bytes32 salt = _getSalt(
            _rawSalt,
            _trustedForwarder,
            _feeSettings,
            _admin,
            _allowList,
            _requirements,
            _name,
            _symbol
        );
        return Create2.computeAddress(salt, keccak256(getBytecode()));
    }

    /**
     * Calculate address without revealing the parameters.
     * @param _salt Salt generated off-chain that includes all the parameters that will be used to create the token
     * @return address of the token that would be created
     */
    function predictProxyAddress(bytes32 _salt) external view returns (address) {
        return Create2.computeAddress(_salt, keccak256(getBytecode()));
    }

    /**
     * @dev Generates the bytecode of the contract to be deployed, using the parameters.
     * @return bytecode of the contract to be deployed.
     */
    function getBytecode() private view returns (bytes memory) {
        return abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, new bytes(0)));
    }

    /**
     * @dev Generates the salt that will be used to deploy the proxy using CREATE2
     * @param _rawSalt value that influences the address of the proxy, but not the initialization
     * @param _trustedForwarder trustedForwarder can not be changed, but is checked for security
     * @param _feeSettings address of the FeeSettings contract to use in the new token
     * @param _admin default-admin of the new token
     * @param _allowList AllowList of the new token
     * @param _requirements Which requirements to use in the new token
     * @param _name token name (e.g. "Test Token")
     * @param _symbol token symbol (e.g. "TST")
     * @return salt that will be used to calculate the address of the token.
     */
    function _getSalt(
        bytes32 _rawSalt,
        address _trustedForwarder,
        IFeeSettingsV2 _feeSettings,
        address _admin,
        AllowList _allowList,
        uint256 _requirements,
        string memory _name,
        string memory _symbol
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _rawSalt,
                    _trustedForwarder,
                    _feeSettings,
                    _admin,
                    _allowList,
                    _requirements,
                    _name,
                    _symbol
                )
            );
    }
}
