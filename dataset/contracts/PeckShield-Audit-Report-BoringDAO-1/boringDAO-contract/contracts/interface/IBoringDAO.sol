// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IBoringDAO {
    // function openTunnel(bytes32 tunnelKey) external;

    function pledge(bytes32 tunnelKey, uint _amount) external;
    function redeem(bytes32 tunnelKey, uint _amount) external;

    function approveMint(bytes32 tunnelKey, string memory _txid, uint _amount, address account, string memory assetAddress) external;
    function burnBToken(bytes32 _tunnelKey, uint _amount, string memory assetAddress) external;

    function getTrustee(uint index) external view returns(address);
    function getTrusteeCount() external view returns(uint);
    function getRandomTrustee() external view returns (address);

}