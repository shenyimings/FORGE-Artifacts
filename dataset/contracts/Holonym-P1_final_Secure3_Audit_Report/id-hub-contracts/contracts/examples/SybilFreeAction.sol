pragma solidity ^0.8.0;
import "../custom-proofs/uniqueness/ISybilResistance.sol";

/* NOTE: you can replace airdrop with any other action that needs Sybil resistance. 
This uses an airdrop as an example, but it can be adapted for voting, play-to-earn, play-to-learn, etc.

Example: You want to give an airdrop to all your early users. You want to make your early users get their fare share and far more than they would get if it was just bots swooping up the airdrop and dumping.
*/
contract SybilFreeAction {
    ISybilResistance registeredActions; // Where actions (including the actionId we care about) are registered
    uint actionId; // The ID for this particular action. You should create your own actionId for the action you want to become sybil-resistant. It can be any number less than the prime number 21888242871839275222246405745257275088548364400416034343698204186575808495617 which hasn't been used as somebody else's actionId. For this, we reccomend you choose a random number in that range.
    mapping (address => bool) hasClaimedAirdrop;

    constructor(uint actionId_) {
        registeredActions = ISybilResistance(0xFcA7AC96b1F8A2b8b64C6f08e993D6A85031333e); //AntiSybilStore address can be found on https://github.com/holonym-foundation/app.holonym.id-frontend/blob/main/src/constants/proofContractAddresses.json
        actionId = actionId_;
    }

    function claimAirdrop() public {
        require(registeredActions.isUniqueForAction(msg.sender, actionId), "You have not yet claimed this action with your Holo");
        require(!hasClaimedAirdrop[msg.sender], "You already got your airdrop!");
        hasClaimedAirdrop[msg.sender] = true;
        _giveAirdrop(msg.sender);
    }

    function _giveAirdrop(address recipient) private {
        // not implemented
    }
}