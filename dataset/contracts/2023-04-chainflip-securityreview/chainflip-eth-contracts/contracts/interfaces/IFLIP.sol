pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IShared.sol";
import "./IAggKeyNonceConsumer.sol";

/**
 * @title    FLIP interface for the FLIP utility token
 */
interface IFLIP is IERC20, IAggKeyNonceConsumer {
    event FlipSupplyUpdated(uint256 oldSupply, uint256 newSupply, uint256 stateChainBlockNumber);

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                  State-changing functions                //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Compares a given new FLIP supply against the old supply,
     *          then mints and burns as appropriate
     * @param sigData               signature over the abi-encoded function params
     * @param newTotalSupply        new total supply of FLIP
     * @param stateChainBlockNumber State Chain block number for the new total supply
     * @param staker Staking contract owner of the tokens to be minted/burnt
     */
    function updateFlipSupply(
        SigData calldata sigData,
        uint256 newTotalSupply,
        uint256 stateChainBlockNumber,
        address staker
    ) external;

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                  Non-state-changing functions            //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Get the last state chain block number that the supply was updated at
     * @return  The state chain block number of the last update
     */
    function getLastSupplyUpdateBlockNumber() external view returns (uint256);
}
