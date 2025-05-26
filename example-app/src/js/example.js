import { AudioSession } from 'ios-audio-session';

window.testEcho = () => {
    const inputValue = document.getElementById("echoInput").value;
    AudioSession.echo({ value: inputValue })
}
