// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ITournament
{
    /*
     * @author data model for tournaments
     */
    struct Tournament
    {
        uint256 tournamentId;
        uint256 endTimestamp;
        uint256 tournamentType;
        uint256[4] elements;
        bool isPaid;
        uint256 rewardId;
    }

    /*
     * @author sets reward count for winner
     */
    function setWinnerRewardCount(uint256 count) external;

    /*
     * @author sets reward count for participation
     */
    function setParticipationRewardCount(uint256 count) external;

    /*
     * @author sets target NFT contract address
     */
    function setNFTContract(address contractAddress) external;

    /*
     * @author sets target consumable / collectible contract address
     */
    function setConsumableContract(address contractAddress) external;

    /*
     * @author sets entrance fee for paid BNB tournaments
     */
    function setPaidTournamentEntranceFee(uint256 fee) external;

    /*
     * @author registers given tokenIds to given tournament
     */
    function register(uint256 tournamentId, uint256[4] memory tokenIds) external payable;

    /*
     * @author sets new tournament
     */
    function setTournament(uint256 endTimestamp, uint256 tournamentType, uint256[4] memory elements, bool isPaid, uint256 rewardId) external;

    /*
     * @author finalizes latest ended tournament
     */
    function endCurrentTournament() external;

    /*
     * @author returns contract balance
     */
    function getContractBalance() external view returns(uint256);

    /*
     * @author returns active tournaments
     */
    function getActiveTournaments() external view returns(Tournament[] memory);

    /*
     * @author returns latest n ended tournaments
     */
    function getLatestEndedTournaments() external view returns(Tournament[] memory, address[] memory);

    /*
     * @author returns tournament of given tournamentId
     */
    function getTournament(uint256 tournamentId) external view returns(Tournament memory);

    /*
     * @author returns tournament winner of given tournamentId
     */
    function getTournamentWinner(uint256 tournamentId) external view returns(address);

    /*
     * @author returns current tournament
     */
    function getCurrentTournament() external view returns(Tournament memory);

    /*
     * @author returns paid tournament entrance fee
     */
    function getPaidTournamentEntryFee() external view returns(uint256);

    /*
     * @author returns participant count of given tournamentId
     */
    function getParticipantCount(uint256 tournamentId) external view returns(uint256);

    /*
     * @author returns rewards for given wallet address
     */
    function getRewards(address walletAddress) external view returns(uint256[] memory);

    /*
     * @author returns if user is joined to given tournamentId or not
     */
    function getIsJoined(uint256 tournamentId, address walletAddress) external view returns(bool);

    /*
     * @author decreases rewards for given wallet address
     */
    function decreaseReward(uint256 tournamentType, address walletAddress) external;

    /*
     * @author decreases consumable rewards for given wallet address
     */
    function decreaseConsumableReward(uint256 amount, address walletAddress) external;
}