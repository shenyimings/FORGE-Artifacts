pragma solidity 0.5.12;

import "./library/DSAuth.sol";

contract DTokenController is DSAuth {
    bool private initialized; // Flags for initializing data

    mapping(address => address) internal dTokens;

    event NewMappingdToken(
        address indexed token,
        address indexed mappingdToken
    );

    constructor() public {
        initialize();
    }

    // --- Init ---
    // This function is used with contract proxy, do not modify this function.
    function initialize() public {
        require(!initialized, "initialize: Already initialized!");
        owner = msg.sender;
        initialized = true;
    }

    /**
     *  @dev Adds new mapping: token => dToken.
     */
    function setdTokensRelation(
        address[] memory _tokens,
        address[] memory _mappingdTokens
    ) public auth {
        require(
            _tokens.length == _mappingdTokens.length,
            "setdTokensRelation: Array length do not match!"
        );
        for (uint256 i = 0; i < _tokens.length; i++) {
            _setdTokenRelation(_tokens[i], _mappingdTokens[i]);
        }
    }

    function _setdTokenRelation(address _token, address _mappingdToken)
        internal
    {
        require(
            dTokens[_token] == address(0x0),
            "_setdTokenRelation: Has set!"
        );
        dTokens[_token] = _mappingdToken;
        emit NewMappingdToken(_token, _mappingdToken);
    }

    /**
     * @dev Updates existing mapping: token => dToken.
     */
    function updatedTokenRelation(address _token, address _mappingdToken)
        external
        auth
    {
        require(
            dTokens[_token] != address(0x0),
            "updatedTokenRelation: token does not exist!"
        );
        dTokens[_token] = _mappingdToken;
        emit NewMappingdToken(_token, _mappingdToken);
    }

    function getdToken(address _token) external view returns (address) {
        return dTokens[_token];
    }
}
