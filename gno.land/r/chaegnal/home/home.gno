package home

import (
	"std"
	"strconv"

	"gno.land/p/chaegnal/ownrandom"
	"gno.land/p/chaegnal/poll"
	"gno.land/p/demo/avl"
	"gno.land/p/demo/mux"
	"gno.land/p/demo/ufmt"
	"gno.land/p/moul/md"
	"gno.land/p/moul/txlink"
)

type Profile struct {
	Name    string
	Pfp     string
	PfpAlt  string
	Email   string
	Github  string
	WhoAmI  string
	AboutMe string
}

var (
	profile           Profile
	pollSpiderPenguin poll.Poll
	router            = mux.NewRouter()
	try               int
)

func init() {
	profile = Profile{
		Name:    "Eva",
		Pfp:     "https://avatars.githubusercontent.com/u/114568162?s=400&u=d754db823981de75bdaea50d1c3a2b607df37f4f&v=4",
		PfpAlt:  "Chaegnal's profile picture",
		Email:   "eva.legrand@epitech.eu",
		Github:  "https://github.com/Chaegnal",
		WhoAmI:  "Hi yall, I'm Eva 👋\n\n",
		AboutMe: "I'm a third year comp-sci student at Epitech based in Paris. In love with coding and learning everyday but also a big fan of penguins and spiderman.\n\n FYI spiderman and I haver never been seen in the same room so... 👀\n\n",
	}

	pollSpiderPenguin = poll.Poll{
		Title:      "Is it a Spiderman fact?",
		Question:   "Can Spiderman see better in the dark than average human ? \n\nTrue if you think Spiderman can / False if you think penguin can",
		VotersTree: avl.NewTree(),
	}

	try = 0
}

func updatePfp(url, alt string) {
	profile.Pfp = url
	profile.PfpAlt = alt
}

func updateAboutMe(newAbout string) {
	profile.AboutMe = newAbout
}

func updateEmail(newMail string) {
	profile.Email = newMail
}

func Vote(vote bool) string {
	txSender := std.OriginCaller()

	voted, _ := pollSpiderPenguin.HasVoted(txSender)
	if voted {
		panic("you've already voted!")
	}

	pollSpiderPenguin.Vote(txSender, vote)

	if vote == true {
		return ufmt.Sprintf("Successfully voted Spiderman for poll Spider or Penguin")
	}
	return ufmt.Sprintf("Successfully voted Penguins for poll Spider or Penguin")
}

func renderAbout() string {
	var display string

	display += md.H2("📖 About me\n\n")

	display += profile.WhoAmI
	display += md.Image(profile.PfpAlt, profile.Pfp)
	display += profile.AboutMe

	return display
}

func renderContact() string {
	var display string

	display += md.H2("🔗 Contact\n\n")

	display += md.Italic("Follow my journey")
	display += " : " + md.Link("Hackerspace", "https://github.com/gnolang/hackerspace/issues/113") + "\n\n"
	display += md.Italic("Email")
	display += " : " + profile.Email + "\n\n"
	display += md.Italic("Github")
	display += " : " + md.Link("@Chaegnal", profile.Github) + "\n"

	return display
}

func renderPoll() string {
	var display string
	var spiderPercent, penguinPercent int

	spider, penguin := pollSpiderPenguin.VoteCount()
	totalVotes := spider + penguin
	if totalVotes != 0 {
		spiderPercent = spider * 100 / totalVotes
		penguinPercent = penguin * 100 / totalVotes
	}

	display += md.H2("📊 Poll") + "\n"
	display += "\n" + pollSpiderPenguin.Title + "\n\n" + pollSpiderPenguin.Question + "\n\n"

	display += "──────────────────────────\n\n"

	display += "🕷️ Spider-Man Votes : " + strconv.Itoa(spider) + " (" + strconv.Itoa(spiderPercent) + "%)\n\n"
	display += "🐧 Penguin Votes    : " + strconv.Itoa(penguin) + " (" + strconv.Itoa(penguinPercent) + "%)\n\n"

	display += "──────────────────────────\n\n"

	display += "Total Votes: " + strconv.Itoa(totalVotes) + "\n"

	return display
}

func fillTry() {
	try++
}

func renderGame() string {
	var display string

	randomIndex := ownrandom.RandomNbr() % 10

	display += md.H2("🎮 Find the Penguin")
	display += "Find the penguin hidden behind one of those links\n\n"

	display += md.Link("Refill your tries", txlink.Call("fillTry"))
	display += " -> Current number of tries: " + strconv.Itoa(try) + "\n\n"

	for i := 0; i <= 9; i++ {
		if i == int(randomIndex) {
			display += "[Here ? 🐧](#)\n\n"
		} else {
			display += "[Here ?](#)\n\n"
		}
	}

	return display
}

func Render(_ string) string {
	var display string

	display += md.HorizontalRule() + "\n"
	display += md.H1("Chaegnal's Home Realm\n\n")
	display += md.HorizontalRule() + "\n"
	display += renderAbout()
	display += md.HorizontalRule() + "\n"
	display += renderPoll() + "\n"
	display += md.HorizontalRule() + "\n"
	display += renderGame() + "\n"
	display += md.HorizontalRule() + "\n"
	display += renderContact()

	display += strconv.FormatInt(ownrandom.RandomNbr()%3, 10)

	return display
}
