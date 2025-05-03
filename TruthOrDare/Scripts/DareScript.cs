using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
using TMPro;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class DareScript : UdonSharpBehaviour
{
    [SerializeField, Tooltip("The TextMeshPro component to display the selected text")]
    private TextMeshPro questionDisplayText;
    
    [SerializeField, Tooltip("Trigger collider that detects players in the game area")]
    public GameObject playerAreaTrigger;
    
    // Array to store players currently in the trigger area (max 256 players in a VRChat instance)
    private VRCPlayerApi[] playersInArea = new VRCPlayerApi[256];
    private int playerCount = 0;
    
    [SerializeField, TextArea(3, 5), Tooltip("Array of dare challenges")]
    private string[] dares = new string[]
    {
        "Kiss the person to your right",
        "Change into a horrendous avatar for 5 minutes",
        "Do your best impression of another player",
        "Speak in a silly voice for the next 3 minutes",
        "Dance to a song of another player's choosing",
        "Tell a joke in the most dramatic way possible",
        "Swap avatars with another player for 2 minutes",
        "Do 10 jumping jacks",
        "Sing your favorite song",
        "Make animal noises for 30 seconds",
        "Pretend to be a news reporter and interview someone",
        "Do your best robot dance",
        "Give someone a hug",
        "Make up a short rap about another player",
        "Play charades - others have to guess what you're acting out",
        "Strike a model pose and hold it for 30 seconds",
        "Tell a scary story in a spooky voice",
        "Do your best superhero pose",
        "Make up a commercial for an imaginary product",
        "Do the chicken dance",
        "Give a dramatic reading of a meme",
        "Do your best evil laugh",
        "Do interpretive dance to someone else's voice",
        "Speak in slow motion for 1 minute",
        "Give 3 people nicknames they must use for 5 minutes",
        "Do your best impression of a famous YouTuber,others guess who",
        "Pretend you're a tour guide of the modern world",
        "Speak in an accent of the group's choosing",
        "Do your best impression of a video game character",
        "Act out a scene from your favorite movie",
        "Do the macarena",
        "Give a fake acceptance speech",
        "Make sound effects for another player's movements",
        "Do your best robot voice",
        "Show your worst and best avatar toggles",
        "Give a fake TED talk for 1 minute",
        "Do your best impression of a cooking show host",
        "Pretend you're a royal monarch for 5 minutes",
        "Give a fake political speech",
        "Make up a dramatic superhero origin story",
        "Pretend you're a museum tour guide",
        "Act like you're in a horror movie",
        "Give a fake award presentation to another player",
        "Do your best impression of an auctioneer",
        "Give a fake fortune telling reading",
        "Make up a battle cry",
        "Pretend you're a drill sergeant",
        "Make up a catchphrase and use it for 5 minutes",
        "Make up a victory dance and perform it",
        "Give a motivational speech",
        "Yell out the first word that comes to mind",
        "Act like an animal of the group's choosing for 1 round",
        "Act like an angry karen for 1 round",
        "Be another player's pet for until it is your turn again",
        "Do 10 squats",
        "Paste your clipboard into the chat",
        "Give another player a lap dance",
        "Play a 'best-of-3' game of rock paper scissors with another player",
        "Take a big sniff of another player and describe it in detail",
        "Do 5 push-ups",
        "Everyone Hydrate!",
        "Perform your favorite yoga pose",
        "Seductively whisper your bedroom fantasies to another player",
        "Take a shot",
        "Take a sip of your drink every time someone says 'um' for the next 2 minutes",
        "Finish 25% of your current drink",
        "Waterfall with your drink for 5 seconds",
        "Go through every toggle on your avatar",
        "Switch to your most embarrassing avatar",
        "Switch to a shader avatar and demonstrate it",
        "Switch between your smallest and largest avatar scale 5 times",
        "Use only emotes to communicate until your next turn",
        "Dance battle using only your avatar's custom animations",
        "Do the splits with FBT or finish your whole drink",
        "Make your avatar as tall as possible and roleplay being a giant for 1 round",
        "Show off your rarest/most expensive avatar",
        "Do a synchronized dance with another player's avatar",
        "Take a group photo with everyone",
        "Become a mute for 1 round",
        "Change your avatar's colors to match another player",
        "Make your avatar as small as possible and roleplay as a rat for 1 round",
        "Play leapfrog with another player",
        "Do the limbo under two players arms",
        "Do your best impression of the VRChat loading screen",
        "Call someone you are close with and tell them you love them",
        "Audibly motorboat another player's chest",
        "Declare a drinking buddy",
        "Lick another player's face",
        "Jump as high as you can IRL",
        "Do 5 sit-ups",
        "For 1 round, end every sentence with 'uwu' or 'owo'",
        "Take a shot",
        "Change into the oldest avatar you have",
        "Talk in an accent of your choice for 1 round",
        "Boop someone",
        "Cuddle with another player for 1 round",
        "Lick the object closest to you IRL",
        "Pretend to be another player for 1 round",
        "Edit your bio to include another player's name with a heart emoji",
        "Take off a piece of clothing",
        "Have another player spank your booty",
        "Talk without closing your mouth for 1 round",
        "Give a compliment to another player",
        "Have another player teach you their favorite dance move",
        "Let another player choose your avatar for the next round",
        "Have a staring contest with another player - first to look away drinks",
        "Do 25 sit-ups",
        "Make up a song and sing it",
        "Do the splits, or go down as far as you can",
        "Do jumping jacks until your next turn", 
        "Passionately make out with your hand",
        "Do your best yodel",
        "Roast everybody that is playing the game",
        "Only speak using song lyrics for the next 3 rounds",
        "Do your best Michael Jackson impersonation",
        "Dance like a ballerina for 1 minute",
        "Say a tongue twister 5 times fast",
        "Communicate only by whistling for the next 5 minutes",
        "Stand on one leg for 10 minutes",
        "Moonwalk across the room",
        "Talk like Shakespeare for the next 3 rounds",
        "Do a wall sit for 30 seconds",
        "You can only walk backwards for the next 2 rounds",
        "Try to kick yourself in the face",
        "Imitate a monkey AND a donkey at the same time",
        "For the next five rounds, any time a player says 'cheese', spank yourself",
        "Sing and dance to YMCA without any music",
        "Tell the most offensive joke you know",
        "Sit on another player's lap until the next round",
        "Try to put your foot behind your head",
        "For the next 5 minutes, only respond by saying 'you know that's right'",
        "Talk with a Russian accent for the next 3 rounds",
        "Do the chicken dance until your next turn",
        "Stand on one leg for the next round",
        "Let another player choose your status for the next 10 minutes"
    };
    
    [UdonSynced]
    private string currentDisplayText = "";
    
    void Start()
    {
        if (questionDisplayText == null)
        {
            Debug.LogError("[DareScript] Question Display Text reference is missing!");
        }
        
        if (playerAreaTrigger == null)
        {
            Debug.LogError("[DareScript] Player Area Trigger reference is missing!");
        }
        
        // Initialize our player array
        playersInArea = new VRCPlayerApi[16];
        playerCount = 0;
    }
    
    public override void OnPlayerTriggerEnter(VRCPlayerApi player)
    {
        if (player != null && player.IsValid())
        {
            // Add player to our array when they enter the trigger
            if (playerCount < playersInArea.Length)
            {
                // Check if player is already in the array
                bool alreadyInArray = false;
                for (int i = 0; i < playerCount; i++)
                {
                    if (playersInArea[i] == player)
                    {
                        alreadyInArray = true;
                        break;
                    }
                }
                
                // If not already in array, add them
                if (!alreadyInArray)
                {
                    playersInArea[playerCount] = player;
                    playerCount++;
                }
            }
        }
    }
    
    public override void OnPlayerTriggerExit(VRCPlayerApi player)
    {
        if (player != null && player.IsValid())
        {
            // Remove player from our array when they exit the trigger
            for (int i = 0; i < playerCount; i++)
            {
                if (playersInArea[i] == player)
                {
                    // Shift all elements down to fill the gap
                    for (int j = i; j < playerCount - 1; j++)
                    {
                        playersInArea[j] = playersInArea[j + 1];
                    }
                    
                    // Clear the last element and decrement count
                    playersInArea[playerCount - 1] = null;
                    playerCount--;
                    break;
                }
            }
        }
    }
    
    public override void Interact()
    {
        DisplayRandomDare();
    }
    
    public void OnDeserialization()
    {
        // Update display text when network data is received
        if (questionDisplayText != null)
        {
            questionDisplayText.text = currentDisplayText;
        }
    }
    
    // Get a random player name from those in the trigger area
    private string GetRandomPlayerName()
    {
        if (playerCount == 0)
        {
            return "another player";
        }
        
        // Get a random player from the array
        int randomIndex = Random.Range(0, playerCount);
        VRCPlayerApi randomPlayer = playersInArea[randomIndex];
        
        if (randomPlayer != null && randomPlayer.IsValid())
        {
            return randomPlayer.displayName;
        }
        
        return "another player";
    }
    
    // Replace "another player" with a random player name
    private string ReplacePlayerNameInText(string text)
    {
        if (text.Contains("another player"))
        {
            string randomPlayerName = GetRandomPlayerName();
            return text.Replace("another player", randomPlayerName);
        }
        
        return text;
    }
    
    public void DisplayRandomDare()
    {
        // Only the owner should change the values
        if (Networking.IsOwner(gameObject))
        {
            if (dares.Length > 0)
            {
                int randomIndex = Random.Range(0, dares.Length);
                string randomDare = dares[randomIndex];
                
                // Replace "another player" with a random player name if needed
                currentDisplayText = ReplacePlayerNameInText(randomDare);
                
                // Update the text locally
                if (questionDisplayText != null)
                {
                    questionDisplayText.text = currentDisplayText;
                }
                
                // Request serialization to sync with all clients
                RequestSerialization();
            }
        }
        else
        {
            // If we're not the owner, request ownership before changing values
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
            SendCustomEventDelayedFrames(nameof(DisplayRandomDare), 1);
        }
    }
}
