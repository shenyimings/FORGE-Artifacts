// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IProtocolConfig {
    function marketConfig() external view returns (address);

    function foreToken() external view returns (address);

    function foreVerifiers() external view returns (address);

    function foundationWallet() external view returns (address);

    function highGuard() external view returns (address);

    function marketplace() external view returns (address);

    function owner() external view returns (address);

    function getTier(
        uint256 tierIndex
    ) external view returns (uint256, uint256);

    function getTierMultiplier(
        uint256 tierIndex
    ) external view returns (uint256);

    function renounceOwnership() external;

    function revenueWallet() external view returns (address);

    function verifierMintPrice() external view returns (uint256);

    function marketCreationPrice() external view returns (uint256);

    function addresses()
        external
        view
        returns (address, address, address, address, address, address, address);

    function roleAddresses() external view returns (address, address, address);

    function isFactoryWhitelisted(address adr) external view returns (bool);
}
