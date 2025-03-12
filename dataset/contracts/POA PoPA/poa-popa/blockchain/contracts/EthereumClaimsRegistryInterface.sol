pragma solidity 0.4.19;


contract EthereumClaimsRegistryInterface {
    function setClaim(address subject, bytes32 key, bytes32 value) external;
    function setSelfClaim(bytes32 key, bytes32 value) external;
    function removeClaim(address issuer, address subject, bytes32 key) external;
    function getClaim(address issuer, address subject, bytes32 key) external view returns(bytes32);
}
