pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";



contract NFTLaunchpad1 is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {

    uint256 public  MAX_NFT_SUPPLY ; // Maximum number of NFTs to be minted
    uint256 public  PRICE_PER_NFT ; // Price per NFT in ether
    uint256 public  MAX_NFT_COUNT ;
    uint256 public  Phase ;
    uint256 public  start_time;
    uint256 public  end_time;

    uint256 private _totalSupply; // Total number of NFTs minted
    bool private _isSaleActive; // Whether the NFT sale is active
    bool public islock = false;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct properties {
        uint256 total_nft;
        uint256 total_price;
    }

    mapping(address => properties) public myDeposits;
    mapping(address => uint256[]) private ownedTokens;

    constructor(string memory _name, string memory _symbol, string memory _imageUrl) ERC721(_name, _symbol) {
        MAX_NFT_COUNT = 1000;
        PRICE_PER_NFT = 0.001 ether;
        MAX_NFT_SUPPLY = 0;
        Phase = 1;
        start_time = 1692173887;
        end_time = 1723796254;
        
        imageUrl = _imageUrl;
    }

    string public imageUrl;

    function mintNFT(string memory _imageUrl) public payable {
        require(start_time <= block.timestamp , "NFT sale is not yet started");
        require(end_time >= block.timestamp , "NFT sale is ended");
        require(MAX_NFT_COUNT >= MAX_NFT_SUPPLY, "Exceeded maximum NFT supply");
        require(msg.value >= PRICE_PER_NFT , "Insufficient ether");
         require( !islock , "Minting function is locked");
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, _imageUrl);
        addToken(msg.sender, newItemId);
        MAX_NFT_SUPPLY = MAX_NFT_SUPPLY + 1;

        myDeposits[msg.sender].total_nft = myDeposits[msg.sender].total_nft + 1;
        myDeposits[msg.sender].total_price = myDeposits[msg.sender].total_price + msg.value;
    }

    /**
     * @dev Withdraw accumulated ether from the contract.
     */
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }

    function reSetter(uint256 count,uint256 price,uint256 supply,uint256 phs, uint256 starttime, uint256 endtime) public onlyOwner {
        MAX_NFT_COUNT = count;
        PRICE_PER_NFT = price * 1000000000000000000;
        MAX_NFT_SUPPLY = supply;
        Phase = phs;
        start_time = starttime;
        end_time = endtime;
    }

    function mintLock() public onlyOwner {
        islock = true;
    }

    function mintRelease() public onlyOwner {
        islock = false;
    }

    function addToken(address owner, uint256 tokenId) internal  {
        ownedTokens[owner].push(tokenId);
    }

    // Function to get the token IDs owned by a specific address
    function getOwnedTokenIds(address owner) external view returns (uint256[] memory) {
        return ownedTokens[owner];
    }

     // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}