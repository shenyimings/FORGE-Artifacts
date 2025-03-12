pragma solidity 0.8.9;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {GaugeImplementation} from "./GaugeImplementation.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GaugesDistributor {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant MIN_DURATION = 1 days;
    uint256 public constant MAX_DURATION = 12 weeks;

    IERC20 public immutable NEURON;
    IERC20 public immutable AXON;
    address public governance;
    address public admin;

    uint256 public pid;
    uint256 public totalWeight;
    bool public isManualWeights = true;

    address[] internal _tokens;
    mapping(address => address) public gauges; // token => gauge
    mapping(address => uint256) public weights; // token => weight
    mapping(address => mapping(address => uint256)) public votes; // msg.sender => votes
    mapping(address => address[]) public tokenVote; // msg.sender => token
    mapping(address => uint256) public usedWeights; // msg.sender => total voting weight of user

    constructor(
        address _neuronToken,
        address _axon,
        address _governance,
        address _admin
    ) {
        NEURON = IERC20(_neuronToken);
        AXON = IERC20(_axon);
        governance = _governance;
        admin = _admin;
    }

    function tokens() external view returns (address[] memory) {
        return _tokens;
    }

    function getGauge(address _token) external view returns (address) {
        return gauges[_token];
    }

    // Reset votes to 0
    function reset() external {
        _reset(msg.sender);
    }

    // Reset votes to 0
    function _reset(address _owner) internal {
        address[] storage _tokenVote = tokenVote[_owner];
        uint256 _tokenVoteCnt = _tokenVote.length;

        for (uint256 i = 0; i < _tokenVoteCnt; i++) {
            address _token = _tokenVote[i];
            uint256 _votes = votes[_owner][_token];

            if (_votes > 0) {
                totalWeight = totalWeight.sub(_votes);
                weights[_token] = weights[_token].sub(_votes);

                votes[_owner][_token] = 0;
            }
        }

        delete tokenVote[_owner];
    }

    // Adjusts _owner's votes according to latest _owner's AXON balance
    function poke(address _owner) public {
        address[] memory _tokenVote = tokenVote[_owner];
        uint256 _tokenCnt = _tokenVote.length;
        uint256[] memory _weights = new uint256[](_tokenCnt);

        uint256 _prevUsedWeight = usedWeights[_owner];
        uint256 _weight = AXON.balanceOf(_owner);

        for (uint256 i = 0; i < _tokenCnt; i++) {
            uint256 _prevWeight = votes[_owner][_tokenVote[i]];
            _weights[i] = _prevWeight.mul(_weight).div(_prevUsedWeight);
        }

        _vote(_owner, _tokenVote, _weights);
    }

    function _vote(
        address _owner,
        address[] memory _tokenVote,
        uint256[] memory _weights
    ) internal {
        _reset(_owner);
        uint256 _tokenCnt = _tokenVote.length;
        uint256 _weight = AXON.balanceOf(_owner);
        uint256 _totalVoteWeight = 0;
        uint256 _usedWeight = 0;

        for (uint256 i = 0; i < _tokenCnt; i++) {
            _totalVoteWeight = _totalVoteWeight.add(_weights[i]);
        }

        for (uint256 i = 0; i < _tokenCnt; i++) {
            address _token = _tokenVote[i];
            address _gauge = gauges[_token];
            uint256 _tokenWeight = _weights[i].mul(_weight).div(_totalVoteWeight);

            if (_gauge != address(0x0)) {
                _usedWeight = _usedWeight.add(_tokenWeight);
                totalWeight = totalWeight.add(_tokenWeight);
                weights[_token] = weights[_token].add(_tokenWeight);
                tokenVote[_owner].push(_token);
                votes[_owner][_token] = _tokenWeight;
            }
        }

        usedWeights[_owner] = _usedWeight;
    }

    function setWeights(address[] memory _tokensToVote, uint256[] memory _weights) external {
        require(
            msg.sender == admin || msg.sender == governance,
            "Set weights function can only be executed by admin or governance"
        );
        require(isManualWeights, "Manual weights mode is off");

        require(_tokensToVote.length == _weights.length, "Number Tokens to vote should be the same as weights number");

        uint256 _tokensCnt = _tokensToVote.length;
        uint256 _totalWeight = 0;
        for (uint256 i = 0; i < _tokensCnt; i++) {
            address _token = _tokensToVote[i];
            address _gauge = gauges[_token];
            uint256 _tokenWeight = _weights[i];

            if (_gauge != address(0x0)) {
                _totalWeight = _totalWeight.add(_tokenWeight);
                weights[_token] = _tokenWeight;
            }
        }
        totalWeight = _totalWeight;
    }

    function setIsManualWeights(bool _isManualWeights) external {
        require(msg.sender == governance, "!governance");

        isManualWeights = _isManualWeights;
    }

    // Vote with AXON on a gauge
    function vote(address[] calldata _tokenVote, uint256[] calldata _weights) external {
        require(_tokenVote.length == _weights.length);
        require(!isManualWeights, "isManualWeights should be false");
        _vote(msg.sender, _tokenVote, _weights);
    }

    function addGauge(address _token, address _gaugeImplementation) external {
        require(msg.sender == governance, "!governance");
        require(gauges[_token] == address(0x0), "exists");

        gauges[_token] = address(
            new ERC1967Proxy(
                _gaugeImplementation,
                abi.encodeWithSelector(GaugeImplementation.initialize.selector, _token, address(NEURON), address(AXON))
            )
        );
        _tokens.push(_token);
    }

    function length() external view returns (uint256) {
        return _tokens.length;
    }

    function distribute(uint256 _duration) external {
        require(
            msg.sender == admin || msg.sender == governance,
            "Distribute function can only be executed by admin or governance"
        );
        require(_duration >= MIN_DURATION && _duration <= MAX_DURATION, "!duration");

        uint256 _balance = NEURON.balanceOf(address(this));

        require(_balance > 0, "!balance");

        if (totalWeight > 0) {
            for (uint256 i = 0; i < _tokens.length; i++) {
                address _token = _tokens[i];
                address _gauge = gauges[_token];
                uint256 _reward = _balance.mul(weights[_token]).div(totalWeight);
                if (_reward > 0) {
                    NEURON.safeApprove(_gauge, 0);
                    NEURON.safeApprove(_gauge, _reward);
                    GaugeImplementation(_gauge).notifyRewardAmount(_reward, _duration);
                }
            }
        }
    }

    function setAdmin(address _admin) external {
        require(msg.sender == admin || msg.sender == governance, "Only governance or admin can set admin");

        admin = _admin;
    }
}
