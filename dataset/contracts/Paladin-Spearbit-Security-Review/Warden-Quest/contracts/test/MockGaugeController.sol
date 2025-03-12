// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Mock GaugeController used for tests
 */
contract MockGaugeController {
    
    uint256 constant public MAXTIME = 4 * 365 * 86400;  // 4 years

    struct VotedSlope {
        uint slope;
        uint power;
        uint end;
    }

    struct Point {
        uint bias;
        uint slope;
    }

    mapping(address => bool) public gaugeCheckpointed;

    // Put storage stuff here
    mapping(address => mapping(uint256 => Point)) point_weights;

    mapping(address => int128) types;

    // gauge => user => vote_slope
    mapping(address => mapping(address => VotedSlope)) userVotes;
    // gauge => user => vote ts
    mapping(address => mapping(address => uint256)) lastUserVote;


    function set_points_weight(address gauge, uint256 period, uint256 bias) external {
        point_weights[gauge][period].bias = bias;
    }

    function points_weight(address gauge, uint256 period) external view returns (Point memory){
        return point_weights[gauge][period];
    }

    function checkpoint_gauge(address gauge) external{
        //No need for implementation here, but this needs to be called on the real GaugeController
        //by the questBoard contract
        gaugeCheckpointed[gauge] = true;
    }

    function add_gauge(address gauge, int128 _type) external {
        require(_type > 0);
        types[gauge] = _type;
    }

    function gauge_types(address gauge) external view returns(int128){
        return types[gauge] - 1;
    }

    function set_user_vote(
        address user,
        address gauge,
        uint256 period,
        uint256 amount,
        uint256 end
    ) external {
        uint256 slope = amount / MAXTIME;
        /*uint256 dt = end - block.timestamp;
        uint256 bias = slope * dt;*/

        userVotes[gauge][user] = VotedSlope(
            slope,
            10000, //We don't care about the percent of balance here, can put all to 100%, since we can put multiple votes per voters
            end
        );

        lastUserVote[gauge][user] = period;
    }

    function vote_user_slopes(address user, address gauge) external view returns(VotedSlope memory){
        return userVotes[gauge][user];
    }

    function last_user_vote(address user, address gauge) external view returns(uint){
        return lastUserVote[gauge][user];
    }
    
}