pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IFLIP.sol";
import "./interfaces/IKeyManager.sol";
import "./AggKeyNonceConsumer.sol";

/**
 * @title    FLIP contract
 * @notice   The FLIP utility token which is used to stake in the FLIP system and pay for
 *           trap fees with
 */
contract FLIP is ERC20, AggKeyNonceConsumer, IFLIP {
    /// @dev    The last block number in which the State Chain updated the totalSupply
    uint256 private _lastSupplyUpdateBlockNum = 0;

    constructor(
        uint256 flipTotalSupply,
        uint256 numGenesisValidators,
        uint256 genesisStake,
        address receiverGenesisValidatorFlip, // Stake Manager
        address receiverGenesisFlip,
        IKeyManager keyManager
    )
        ERC20("Chainflip", "FLIP")
        nzAddr(receiverGenesisValidatorFlip)
        nzAddr(receiverGenesisFlip)
        nzUint(flipTotalSupply)
        AggKeyNonceConsumer(keyManager)
    {
        uint256 genesisValidatorFlip = numGenesisValidators * genesisStake;
        _mint(receiverGenesisValidatorFlip, genesisValidatorFlip);
        _mint(receiverGenesisFlip, flipTotalSupply - genesisValidatorFlip);
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                  State-changing functions                //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Compares a given new FLIP supply against the old supply,
     *          then mints or burns as appropriate. The message must be 
     '          signed by the aggregate key.
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
    )
        external
        override
        nzUint(newTotalSupply)
        nzAddr(staker)
        consumesKeyNonce(
            sigData,
            keccak256(
                abi.encodeWithSelector(
                    this.updateFlipSupply.selector,
                    SigData(sigData.keyManAddr, sigData.chainID, 0, 0, sigData.nonce, address(0)),
                    newTotalSupply,
                    stateChainBlockNumber,
                    staker
                )
            )
        )
    {
        require(stateChainBlockNumber > _lastSupplyUpdateBlockNum, "FLIP: old FLIP supply update");
        _lastSupplyUpdateBlockNum = stateChainBlockNumber;
        uint256 oldSupply = totalSupply();
        if (newTotalSupply < oldSupply) {
            uint256 amount = oldSupply - newTotalSupply;
            _burn(staker, amount);
        } else if (newTotalSupply > oldSupply) {
            uint256 amount = newTotalSupply - oldSupply;
            _mint(staker, amount);
        }
        emit FlipSupplyUpdated(oldSupply, newTotalSupply, stateChainBlockNumber);
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                  Non-state-changing functions            //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Get the last state chain block number of the last supply update
     * @return  The state chain block number of the last supply update
     */
    function getLastSupplyUpdateBlockNumber() external view override returns (uint256) {
        return _lastSupplyUpdateBlockNum;
    }
}
