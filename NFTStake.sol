// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract StakingContract is ERC20,ERC721Holder,Ownable {
    IERC20 public rewardToken;
    IERC721 public nft1;
    uint256 public start_time;
    uint256 public end_time;
    uint256 public totalReward;
    uint256 public timeInSeconds;

    uint256 public totalStaked;
    uint256 public global_time = start_time;
    // uint256 rewards;

    mapping(uint256 => address) public tokenOwnerOf1;
    mapping(uint256 => uint256) public tokenStakedAt1;
    mapping(address => uint256) public amountStaked1;
    uint256 public totalStaked1;


    mapping(address => address) public users;
    mapping(address => bool) public hasStaked;
    uint256 public userCount;


    // uint256 public EMISSION_RATE = (1 * 10 ** decimals()) / 1 minutes;
    // uint256 private rewardsPerCycle = 100000;
    

    constructor(address _rewardToken, address _nft1, uint256 _totalReward, uint256 _timeInSeconds, uint256 _end_time) ERC20("MyToken", "MTK") Ownable(msg.sender){
        rewardToken = IERC20(_rewardToken);
        nft1 = IERC721(_nft1);
        start_time = block.timestamp;
        end_time = _end_time;
        totalReward = _totalReward;
        timeInSeconds = _timeInSeconds;
    }

    function migrateReward() public onlyOwner{
        require(rewardToken.balanceOf(msg.sender) >= totalReward);
        rewardToken.transferFrom(msg.sender, address(this), totalReward);

    }

    

    function stake(uint256 tokenId)  external  {
        nft1.safeTransferFrom(msg.sender, address(this), tokenId);
        tokenOwnerOf1[tokenId] = msg.sender;
        tokenStakedAt1[tokenId] = block.timestamp;
        amountStaked1[msg.sender] = amountStaked1[msg.sender] + 1;
        totalStaked1 = totalStaked1 + 1;
        totalStaked = totalStaked + 1;
        global_time = block.timestamp;
        users[msg.sender] = msg.sender;
        if(!hasStaked[msg.sender]){
            userCount++;
            hasStaked[msg.sender] = true;
        }
    }

    

    function calculateTokens(uint256 tokenStakedAt) public view returns (uint256) {
        require( tokenStakedAt != 0, "Required stake time not reached");
        // uint256 rewardmath = 0 ;
        // uint256 earned = 0;
        uint256 reward = 0 ;
        uint256 stakePercent = (((block.timestamp - tokenStakedAt) * 100) / (end_time - start_time));
        reward = ((totalReward / totalStaked) * stakePercent) / 100;
        // earned= rewardmath / 100;
        // uint256 timeInterval =  block.timestamp - global_time ;
        // reward = ((earned * totalStaked * 1000000000000000000) / (timeInterval * (totalReward/10)));
        // if(userCount == 0){
        //     return reward;
        // }
        // else {
        //     return (reward / userCount);
        // }
        return reward;
        
    }

    function claimAmount(uint256 tokenId) public view  returns (uint256) {
        uint256 rewards = 0;
        
        require( tokenStakedAt1[tokenId] != 0, "Required stake time not reached");  
        // uint256 rewardmath = 0 ;
        // uint256 earned = 0;
        
        uint256 stakePercent = (((block.timestamp - tokenStakedAt1[tokenId]) * 100) / (end_time - start_time));
        rewards = ((totalReward / totalStaked) * stakePercent) / 100;
        // earned= rewardmath / 100;
        // uint256 timeInterval =  block.timestamp - global_time ;
        // rewards = ((earned * totalStaked * 1000000000000000000) / ( timeInterval * (totalReward/10)));
       
        
        // if(userCount == 0){
        //     return rewards;
        // }
        // else {
        //     return (rewards / userCount);
        // }
        return rewards;
    }

  

    function unstake(uint256 tokenId) external  {
    require(tokenOwnerOf1[tokenId] == msg.sender, "You can't unstake");
    require((block.timestamp - tokenStakedAt1[tokenId]) > 1 days, "Time Limit not reached");
    
    // Calculate the amount of tokens to transfer
    uint256 tokensToTransfer = calculateTokens(tokenStakedAt1[tokenId]);

    
    // Transfer ERC20 tokens from contract to the user
    require(rewardToken.transfer(msg.sender, tokensToTransfer), "Token transfer failed");
    totalReward = totalReward - tokensToTransfer;
    
    // Transfer ERC721 token from contract to the user
    nft1.transferFrom(address(this), msg.sender, tokenId);
    
    // Clean up token information
    delete tokenOwnerOf1[tokenId];
    delete tokenStakedAt1[tokenId];
    totalStaked1--;
    totalStaked--;
    global_time = block.timestamp;
    amountStaked1[msg.sender] = amountStaked1[msg.sender] - 1;
    if((amountStaked1[msg.sender]) == 0){
                delete users[msg.sender];
                userCount--;
                delete hasStaked[msg.sender];
            }
    }

   

    

    function emergency_withdraw(uint256 tokenId) external  {
        require(tokenOwnerOf1[tokenId] == msg.sender, "You can't unstake");
        nft1.transferFrom(address(this), msg.sender, tokenId);
        delete tokenOwnerOf1[tokenId];
        delete tokenStakedAt1[tokenId];
        totalStaked1 = totalStaked1 - 1;
        totalStaked = totalStaked - 1;
        global_time = block.timestamp;
        amountStaked1[msg.sender] = amountStaked1[msg.sender] - 1;
        if((amountStaked1[msg.sender] ) == 0){
                delete users[msg.sender];
                userCount--;
                delete hasStaked[msg.sender];
            }
    } 

    

    function setNFT1(address newNFT1) external onlyOwner {
        nft1 = IERC721(newNFT1);
    }


    function setrewardToken(address newrewardToken) external onlyOwner {
        rewardToken = IERC20(newrewardToken);
    }

    function settimeInSeconds(uint256 _timeInSeconds) external onlyOwner {
        timeInSeconds = _timeInSeconds;
    }

    function reSetter(address _rewardToken, address _nft1, uint256 _totalReward, uint256 _timeInSeconds) public onlyOwner {
       rewardToken = IERC20(_rewardToken);
        nft1 = IERC721(_nft1);
        start_time = block.timestamp;
        totalReward = _totalReward;
        timeInSeconds = _timeInSeconds;
        require(rewardToken.transferFrom(msg.sender, address(this), totalReward), "No token balance");
    }

    function _totalRewards() public view returns (uint256) {
        return totalReward;
    }

    function _totalStaked() public view returns (uint256) {
        return totalStaked;
    }

    function getWalletIDFromContract (address _contract, address wallet, uint256 bal) external view returns (uint256[] memory) {
        uint256[] memory ids = new uint256[](bal);
        for (uint256 i = 0; i < bal; i++) {
            ids[i] = IERC721Enumerable(_contract).tokenOfOwnerByIndex(wallet, i);
        }
        return ids;
    }

}

