// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./TycheStakeTemple.sol";

contract TycheStake is Ownable {
    event NewStakeContract(
        address indexed smartChef, 
        address stakeToken, 
        address rewardToken, 
        uint256 rewardPerBlock, 
        uint256 startBlock, 
        uint256 endBlock,
        uint256 poolLimitPerUser,
        address feeAddress,
        address stakeOwner
    );

    /**
     * @notice Initialize the contract
     * @param _stakedToken: staked token address
     * @param _rewardToken: reward token address
     * @param _rewardPerBlock: reward per block (in rewardToken)
     * @param _startBlock: start block
     * @param _endBlock: end block
     * @param _poolLimitPerUser: pool limit per user in stakedToken (if any, else 0)
     * @param _feeAddress: fee address
     * param _admin: admin address with ownership
     */
    function deployPool(
        IERC721 _stakedToken,
        address _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _poolLimitPerUser,
        address _feeAddress
        // address _admin  // change to owner
    ) external onlyOwner {
        require(IRewardToken(_rewardToken).totalSupply() >= 0);

        bytes memory bytecode = type(TycheStakeTemple).creationCode;
        bytes32 salt = keccak256(
            abi.encodePacked(_stakedToken, _rewardToken, _startBlock)
        );
        address smartChefAddress;

        assembly {
            smartChefAddress := create2(
                0,
                add(bytecode, 32),
                mload(bytecode),
                salt
            )
        }

        TycheStakeTemple(smartChefAddress).initialize(
            _stakedToken,
            _rewardToken,
            _rewardPerBlock,
            _startBlock,
            _endBlock,
            _poolLimitPerUser,
            _feeAddress,
            msg.sender
        );

        emit NewStakeContract(smartChefAddress, address(_stakedToken), _rewardToken, _rewardPerBlock, _startBlock, _endBlock, _poolLimitPerUser, _feeAddress, msg.sender);
    }
}