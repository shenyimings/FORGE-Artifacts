// contracts/ETNPriorityTransactorsInterface.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;
  
interface ETNPriorityTransactorsInterface {
    struct TransactorMeta {
        bool isGasPriceWaiver;
        string publicKey;
        string name;
    }

    function getTransactors() external view returns (TransactorMeta[] memory);
    function getTransactorByKey(string memory _publicKey) external view returns (TransactorMeta memory);
}
