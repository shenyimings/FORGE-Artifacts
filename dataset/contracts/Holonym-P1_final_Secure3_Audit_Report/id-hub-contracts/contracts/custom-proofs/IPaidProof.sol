pragma solidity ^0.8.0;
interface IPaidProof {
    function setPrice(uint newPrice) external;
    function collectPayments() external;
    function allowIssuers(uint[] memory issuerAddresses) external;
    function revokeIssuers(uint[] memory issuerAddresses) external;
    function isValidIssuer(uint issuerAddress) external view returns (bool);
}
