shader_type canvas_item;
// Post-traitement de RESPIRE.
// Objectif : donner au rendu GL Compatibility la texture d'une pellicule
// argentique poussée — grain, vignettage lourd, désaturation, et une
// aberration chromatique qui s'ouvre avec la peur.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

uniform float grain : hint_range(0.0, 0.3) = 0.055;
uniform float vignette_force : hint_range(0.0, 2.0) = 1.05;
uniform float aberration : hint_range(0.0, 0.02) = 0.0012;
uniform float peur : hint_range(0.0, 1.0) = 0.0;       // 0..1
uniform float desat : hint_range(0.0, 1.0) = 0.28;
uniform float noirceur : hint_range(0.0, 1.0) = 0.0;   // fondu au noir
uniform float souffle : hint_range(0.0, 1.0) = 1.0;    // 1 = plein, 0 = vide
uniform float t = 0.0;
// Impulsion de bruit : 0 au repos, 1 juste apres un bruit qui porte loin.
// Un bruit qui porte revele brievement la taille du couloir — le vignettage
// s'ouvre, puis se referme. C'est le seul retour du jeu sur sa mecanique
// centrale, et il est entierement diegetique : pas de jauge, pas de chiffre.
// Le joueur apprend la portee de ses pas en voyant la piece lui repondre.
// Accroupi rien ne bouge ; en courant, le couloir s'ouvre en grand.
uniform float bruit : hint_range(0.0, 1.0) = 0.0;
// direction ecran de la Veilleuse pendant la traque, et force du signal
uniform vec2 menace = vec2(0.0, 0.0);
uniform float menace_force : hint_range(0.0, 1.0) = 0.0;
// correction de luminosité choisie par le joueur : 1.0 = neutre
uniform float gamma : hint_range(0.5, 2.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.31, 289.07))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);

	// --- battement : la vision se resserre au rythme du coeur ---
	float bpm = mix(1.1, 2.4, peur);
	float beat = sin(t * bpm * 6.2831);
	beat = pow(max(beat, 0.0), 6.0);                     // pic bref, comme un pouls
	float pulse = beat * peur * 0.035;

	// --- aberration chromatique, radiale, ouverte par la peur ---
	float ab = aberration + peur * 0.0045 + pulse * 0.04;
	vec2 dir = c * (1.0 + r2 * 1.6);
	vec3 col;
	col.r = texture(screen_tex, uv - dir * ab).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv + dir * ab).b;

	// --- désaturation : plus on manque d'air, plus le monde se vide ---
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	float d = desat + (1.0 - souffle) * 0.40 + peur * 0.12;
	col = mix(col, vec3(lum), clamp(d, 0.0, 0.95));
	// virage froid dans les ombres, chaud dans les hautes lumières
	col *= mix(vec3(0.90, 0.95, 1.05), vec3(1.02, 1.00, 0.95), smoothstep(0.0, 0.55, lum));

	// --- contraste « bain d'argent » ---
	col = clamp((col - 0.5) * 1.16 + 0.5, 0.0, 4.0);

	// --- vignettage ---
	// `bruit` repousse le rayon du vignettage vers l'exterieur : la piece
	// s'ouvre au lieu de s'eclaircir. C'est le meme levier que le battement
	// cardiaque juste au-dessus, et il porte bien plus loin qu'un simple
	// ajout de lumiere — une addition se noie dans des pixels deja noirs.
	float r2v = r2 * (1.0 + pulse * 12.0) * (1.0 - bruit * 0.36);
	float vig = 1.0 - smoothstep(0.16, 0.78, r2v) * vignette_force;
	vig = clamp(vig, 0.0, 1.0);
	// le manque d'air ferme le champ
	vig *= 1.0 - (1.0 - souffle) * 0.45 * smoothstep(0.05, 0.55, r2);

	col *= vig;

	// Le recul du vignettage ne suffit pas seul : dans une piece non eclairee
	// il n'ouvre que sur du noir, et le retour disparaitrait precisement la ou
	// le joueur en a le plus besoin. Ce voile, lui, ne depend d'aucune lumiere
	// presente — le bruit rend brievement l'espace perceptible meme dans le
	// noir complet. Froid et tres faible : on suggere un volume, on n'eclaire pas.
	col += bruit * 0.030 * smoothstep(0.05, 0.45, r2) * vec3(0.82, 0.88, 1.0);

	// --- d'ou vient la menace ---
	// Pendant la traque, l'ombre se referme du cote ou elle se trouve. Dans un
	// couloir noir c'est souvent la seule information de direction dont dispose
	// le joueur : sans elle, une chasse n'est qu'une mort tiree au sort.
	// L'ecchymose bat au rythme du coeur, pour rester une sensation et non un
	// element d'interface.
	if (menace_force > 0.001) {
		float vers = clamp(dot(normalize(c + vec2(1e-5)), menace), 0.0, 1.0);
		float ecchymose = pow(vers, 2.4) * menace_force
				* smoothstep(0.015, 0.26, r2) * (0.78 + 0.22 * beat);
		col = mix(col, col * vec3(0.46, 0.26, 0.30), clamp(ecchymose, 0.0, 0.9));
	}

	// --- grain animé ---
	float g = hash(uv * vec2(1920.0, 1080.0) + vec2(t * 71.3, t * 37.9));
	col += (g - 0.5) * (grain + peur * 0.045);

	col *= (1.0 - noirceur);
	// appliquée en dernier, sur l'image finale
	col = pow(max(col, vec3(0.0)), vec3(1.0 / max(gamma, 0.05)));
	COLOR = vec4(col, 1.0);
}
