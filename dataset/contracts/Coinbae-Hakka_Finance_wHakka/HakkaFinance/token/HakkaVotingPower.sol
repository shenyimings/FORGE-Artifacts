pragma solidity 0.5.17;

contract sHakka {
    function totalSupply() external view returns (uint256);
    function votingPower(address staker) external view returns (uint256);
}

contract HakkaVotingPower {
    sHakka constant SHAKKA = sHakka(0xd9958826Bce875A75cc1789D5929459E6ff15040);

    string public name = "HakkaVotingPower";
    string public symbol = "HVP";
    uint8 public decimals = 18;

    function totalSupply() external view returns (uint256) {
        return SHAKKA.totalSupply();
    }

    function balanceOf(address staker) external view returns (uint256) {
        return SHAKKA.votingPower(staker);
    }

}