pragma solidity ^0.8.0;
import "../custom-proofs/residency/IIsUSResident.sol";

// US Residents have had it hard this year! let's send 1 gwei to anyone who can prove they're from the US
contract USResidency {
    IIsUSResident resStore;
    constructor() {
        resStore = IIsUSResident(0x42D6007317CED2281a64aCc052cE57e3d92bf912); //ResidencyStore address can be found on https://github.com/holonym-foundation/app.holonym.id-frontend/blob/main/src/constants/proofContractAddresses.json
    }

    // NOTE: there are better ways to send ETH. Please don't copy this code
    function sendStimmy() public {
        require(resStore.usResidency(msg.sender), "You have not proven you are from the US");
        payable(msg.sender).send(1);
    }
}