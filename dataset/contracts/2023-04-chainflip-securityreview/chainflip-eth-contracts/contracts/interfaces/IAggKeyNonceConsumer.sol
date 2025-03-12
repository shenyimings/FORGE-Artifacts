pragma solidity ^0.8.0;

import "./IShared.sol";
import "./IKeyManager.sol";

/**
 * @title    AggKeyNonceConsumer interface
 */

interface IAggKeyNonceConsumer is IShared {
    event UpdatedKeyManager(address keyManager);

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                  State-changing functions                //
    //                                                          //
    //////////////////////////////////////////////////////////////
    /**
     * @notice  Update KeyManager reference. Used if KeyManager contract is updated
     * @param sigData   The keccak256 hash over the msg (uint) (here that's normally
     *                  a hash over the calldata to the function with an empty sigData) and
     *                  sig over that hash (uint) from the aggregate key
     * @param keyManager New KeyManager's address
     */
    function updateKeyManager(SigData calldata sigData, IKeyManager keyManager) external;

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                          Getters                         //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Get the KeyManager address/interface that's used to validate sigs
     * @return  The KeyManager (IKeyManager)
     */
    function getKeyManager() external view returns (IKeyManager);
}
