<?php
use Restserver\Libraries\REST_Controller;
defined('BASEPATH') OR exit('No direct script access allowed');

if (isset($_SERVER['HTTP_ORIGIN'])) {
    header("Access-Control-Allow-Origin: {$_SERVER['HTTP_ORIGIN']}");
    header('Access-Control-Allow-Credentials: true');
    header('Access-Control-Max-Age: 86400');
}
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    if (isset($_SERVER['HTTP_ACCESS_CONTROL_REQUEST_METHOD']))
        header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
    if (isset($_SERVER['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']))
        header("Access-Control-Allow-Headers: {$_SERVER['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']}");
    exit(0);
}

require APPPATH . 'libraries/REST_Controller.php';
require APPPATH . 'libraries/Format.php';

/**
 * Mobile API Controller   V1_fp
 *
 * FIX: Images are physically stored under the React/EDI app at
 *      https://civ-dev.codeonline-edi.net/
 *      The DB stores relative paths such as "/images/products/filename.jpg".
 *      This API normalises every image path to a full absolute URL so the
 *      mobile app (https://civ-fp.codeonline-edi.net/) can fetch them
 *      without knowing where the files actually live.
 */
class V1_fp extends REST_Controller {

    /**
     * Base URL of the server that physically hosts the uploaded images.
     * This is the React / Edi-dev app domain   NOT the mobile-app domain.
     * Change this constant if the React app ever moves to a different domain.
     */
    const IMAGES_BASE_URL = 'https://civ-dev.codeonline-edi.net';

    function __construct()
    {
        parent::__construct();
        $this->load->model('api_fp/api_model_fp');
    }

    /**
     * Normalise a single image path to a full absolute URL.
     *
     * Rules:
     *  - Already absolute (http:// or https://)  ? returned as-is
     *  - Relative path starting with "/"          ? prepend IMAGES_BASE_URL
     *  - Anything else (empty, null, whitespace)  ? skip (returns null)
     *
     * @param  string $path  Raw value from the DB
     * @return string|null   Absolute URL or null if the path is unusable
     */
    private function _resolve_image_url($path)
    {
        if (empty($path) || trim($path) === '') {
            return null;
        }
        $path = trim($path);
        // Already absolute
        if (strpos($path, 'http://') === 0 || strpos($path, 'https://') === 0) {
            return $path;
        }
        // Chemin relatif -> prefixer avec le host images (config par pays: $config['images_base_url'],
        // fallback sur la constante si non configure).
        $base = $this->config->item('images_base_url');
        if (empty($base)) { $base = self::IMAGES_BASE_URL; }
        return rtrim($base, '/') . '/' . ltrim($path, '/');
    }

    /**
     * Explode the semicolon-separated images column and resolve every path.
     * Returns a plain array of absolute image URLs (empty values are dropped).
     *
     * @param  string|null $raw  Value of the `images` column
     * @return array
     */
    private function _parse_images($raw)
    {
        if ($raw === null || $raw === '') {
            return [];
        }
        $parts  = explode(';', $raw);
        $result = [];
        foreach ($parts as $part) {
            $url = $this->_resolve_image_url($part);
            if ($url !== null) {
                $result[] = $url;
            }
        }
        return $result;
    }

    /**
     * Resolve an entity's logo filename to a full absolute URL.
     *
     * The web admin (server.js) stores company logos as a BARE filename in
     * `Entite.logo` (see multer's `uploadLogo.single('logo')` on
     * POST/PUT /api/companies) and serves them statically at
     * `/images/logo_entite/<filename>` via
     * `app.use('/images/logo_entite', express.static(logosDir))`.
     * This mirrors that same layout on top of the same images host used by
     * `_resolve_image_url()`, so the mobile app can render entity logos
     * without knowing anything about the web app's disk layout.
     *
     * @param  string|null $filename  Raw value of the `Entite.logo` column
     * @return string|null            Absolute URL or null if no logo is set
     */
    private function _resolve_logo_url($filename)
    {
        if (empty($filename) || trim($filename) === '') {
            return null;
        }
        $filename = trim($filename);
        // Already absolute (defensive - logos are normally saved as a bare filename)
        if (strpos($filename, 'http://') === 0 || strpos($filename, 'https://') === 0) {
            return $filename;
        }
        $base = $this->config->item('images_base_url');
        if (empty($base)) { $base = self::IMAGES_BASE_URL; }
        return rtrim($base, '/') . '/images/logo_entite/' . ltrim($filename, '/');
    }

    // -----------------------------------------------------------------------
    // GET  fiche_produit_by_gtin
    // -----------------------------------------------------------------------
    public function fiche_produit_by_gtin_get()
    {
        $xlang = $this->input->get_request_header('x-lang');
        switch ($xlang) {
            case 'fr-FR': $x_lang = 'fr'; break;
            case 'en-US': $x_lang = 'en'; break;
            default:      $x_lang = 'fr';
        }

        $response = $this->api_model_fp->fiche_produit_gtin($this->get('gtin'));

        if (!empty($response)) {
            // *** FIX: resolve image paths to absolute URLs ***
            $response['images'] = $this->_parse_images(
                is_array($response['images']) ? implode(';', $response['images']) : $response['images']
            );

            $response['netContent']         = '';
            $response['unitCodeNetContent'] = '';
            if ($response['telephone'] == null) { $response['telephone'] = ''; }
            if ($response['email']     == null) { $response['email']     = ''; }
            if ($response['site']      == null) { $response['site']      = ''; }

            switch ($response['codeCader']) {
                case 'Libre':       $response['codeCaderAr'] = '??';    break;
                case 'Subventionne':$response['codeCaderAr'] = '????';  break;
                case 'Encadre':     $response['codeCaderAr'] = '????';  break;
                default:            $response['codeCaderAr'] = '';
            }

            $response['serveur']       = 'local';
            $response['libelleBrique'] = $response['libelleBrique_' . $x_lang];
            unset($response['libelleBrique_fr']);
            unset($response['libelleBrique_en']);

            $this->response($response, REST_Controller::HTTP_OK);
        } else {
            $hub = $this->registry_fp($this->get('gtin'));
            if (!empty($hub)) {
                $this->response($hub, REST_Controller::HTTP_OK);
            } else {
                $this->gs1_FP($this->get('gtin'));
            }
        }
    }

    // -----------------------------------------------------------------------
    // GS1 fallback lookup
    // -----------------------------------------------------------------------
    function auth()
    {
        $username = 'GS1_API_USERNAME_REDACTED';   // SECRET tiers GS1 France — à remettre depuis le serveur/.env au déploiement
        $password = 'GS1_API_PASSWORD_REDACTED';   // (ne pas committer en clair ; idéalement déplacer en .env)
        $clt = curl_init();
        curl_setopt($clt, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($clt, CURLOPT_URL, 'https://api.gs1.fr/auth/connect/token');
        curl_setopt($clt, CURLOPT_POST, true);
        curl_setopt($clt, CURLOPT_USERPWD, $username . ':' . $password);
        curl_setopt($clt, CURLOPT_POSTFIELDS, [
            'grant_type' => 'client_credentials',
            'scope'      => 'Products.Read'
        ]);
        $auth_response = curl_exec($clt);
        if ($auth_response === false) {
            curl_close($clt);
            $this->response('NULL', REST_Controller::HTTP_OK);
        }
        curl_close($clt);
        return json_decode($auth_response, true);
    }

    public function gs1_FP($gtin)
    {
        $token = $this->auth();
        $ch = curl_init('https://api.gs1.fr/products/' . $gtin . '?api-version=v2');
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'Authorization: Bearer ' . $token['access_token'],
            'Ocp-Apim-Subscription-Key: 13295cd4d95d487fab03315fb1219e86'
        ]);
        $data = curl_exec($ch);
        curl_close($ch);

        if ($data === '"Invalid control key"') {
            $this->response(['message' => 'Invalid control key'], REST_Controller::HTTP_NOT_FOUND);
        } elseif ($data === '"Invalid GTIN format. Please enter a GTIN code of 8,12, 13 or 14 characters"') {
            $this->response(['message' => 'Format GTIN invalide. Veuillez saisir un code GTIN de 13 ou 14 caract res'], REST_Controller::HTTP_NOT_FOUND);
        } else {
            $GFP = json_decode($data, true);
            $brand         = !empty($GFP['itemOffered']['brand']['brandName'][0]['value'])        ? $GFP['itemOffered']['brand']['brandName'][0]['value']        : '';
            $subBrand      = !empty($GFP['itemOffered']['brand']['subBrandName'])                 ? $GFP['itemOffered']['brand']['subBrandName']                 : '';
            $productName   = !empty($GFP['itemOffered']['productDescription'][0]['value'])        ? $GFP['itemOffered']['productDescription'][0]['value']        : '';
            $shortName     = $productName;
            $gtin_val      = !empty($GFP['itemOffered']['gtin'])                                  ? $GFP['itemOffered']['gtin']                                  : '';
            $libelleBrique = !empty($GFP['itemOffered']['gpcDescription'])                        ? $GFP['itemOffered']['gpcDescription']                        : '';
            $netContent    = !empty($GFP['itemOffered']['netContent'][0]['quantity'])             ? $GFP['itemOffered']['netContent'][0]['quantity']             : '';
            $unitCode      = !empty($GFP['itemOffered']['netContent'][0]['unitCode'])             ? $GFP['itemOffered']['netContent'][0]['unitCode']             : '';
            $companyName   = !empty($GFP['itemOffered']['brandOwner']['companyName'])             ? $GFP['itemOffered']['brandOwner']['companyName']             : '';
            $gln           = !empty($GFP['itemOffered']['brandOwner']['globalLocationNumber'])    ? $GFP['itemOffered']['brandOwner']['globalLocationNumber']    : '';

            $this->response([
                'images'              => [],   // GS1 images are external   no path to rewrite
                'brand'               => $brand,
                'subBrand'            => $subBrand,
                'productName'         => $productName,
                'shortName'           => $shortName,
                'gtin'                => $gtin_val,
                'countryOfOrigin'     => '',
                'libelleBrique'       => $libelleBrique,
                'prixMin'             => '',
                'prixMax'             => '',
                'codeCader'           => '',
                'netContent'          => $netContent,
                'unitCodeNetContent'  => $unitCode,
                'companyName'         => $companyName,
                'gln'                 => $gln,
                'adresse'             => '',
                'telephone'           => '',
                'email'               => '',
                'site'                => '',
                'codeCaderAr'         => '',
                'serveur'             => 'gs1Organization'
            ], REST_Controller::HTTP_OK);
        }
    }

    // -----------------------------------------------------------------------
    // registry_fp — proxys minces vers le Hub PAESN (fallback cross-pays)
    // -----------------------------------------------------------------------
    private function registry_fp($gtin)
    {
        return $this->registry_call('/api/registry/fp?gtin=' . urlencode($gtin));
    }
    private function registry_fp_brand_categories($brand)
    {
        return $this->registry_call('/api/registry/fp/brand-categories?brand=' . urlencode($brand));
    }
    private function registry_fp_products($brand, $categoryCode, $page)
    {
        return $this->registry_call('/api/registry/fp/products?brand=' . urlencode($brand)
            . '&categoryCode=' . urlencode($categoryCode) . '&page=' . urlencode($page));
    }
    private function registry_call($path)
    {
        // Hub registry + clé lus depuis la config ($config['registry_hub_url'] / ['registry_hub_key']).
        // Fallback historique (hub DEV) uniquement si non configuré.
        $hub_url = $this->config->item('registry_hub_url');
        $hub_key = $this->config->item('registry_hub_key');
        if (empty($hub_url) || empty($hub_key)) {
            $hub_url = 'http://217.182.94.86:5010';
            $hub_key = 'REG-EDI-2026-9b9909f7d244d103ef4d09cb';
        }
        $xlang   = $this->input->get_request_header('x-lang');
        $ch = curl_init($hub_url . $path);
        curl_setopt_array($ch, array(
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 4,
            CURLOPT_HTTPHEADER     => array('x-registry-key: ' . $hub_key, 'x-lang: ' . $xlang),
        ));
        $out  = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        if ($out === false || $code != 200) { return null; }
        return json_decode($out, true);
    }

    // -----------------------------------------------------------------------
    // GET  fiche_produit  (full list)
    // -----------------------------------------------------------------------
    public function fiche_produit_get()
    {
        $response = $this->api_model_fp->fiche_produit();
        $this->response($response, REST_Controller::HTTP_OK);
    }

    // -----------------------------------------------------------------------
    // GET  sponsors
    // -----------------------------------------------------------------------
    public function sponsors_get()
    {
        $xlang = $this->input->get_request_header('x-lang');
        switch ($xlang) {
            case 'fr-FR': $x_lang = 'FR'; break;
            case 'en-US': $x_lang = 'EN'; break;
            default:      $x_lang = 'EN';
        }

        $sponsors = $this->api_model_fp->all_sponsors();
        if (!empty($sponsors)) {
            if (count($sponsors) == 1) {
                $tablesponsors = [$sponsors[0]['url']];
            } else {
                $stable = '';
                foreach ($sponsors as $row) {
                    $stable .= $row['url'] . ';';
                }
                $stable        = rtrim($stable, ';');
                $tablesponsors = explode(';', $stable);
            }

            $titres_menu = $this->api_model_fp->get_titres_menu();
            $tablesmenu  = [
                (object) ['index' => 0, 'ar' => $titres_menu['Text_menu1_ar'], 'fr' => $titres_menu['Text_menu1_fr'], 'en' => $titres_menu['Text_menu1_en']],
                (object) ['index' => 1, 'ar' => $titres_menu['Text_menu2_ar'], 'fr' => $titres_menu['Text_menu2_fr'], 'en' => $titres_menu['Text_menu2_en']],
                (object) ['index' => 2, 'ar' => $titres_menu['Text_menu3_ar'], 'fr' => $titres_menu['Text_menu3_fr'], 'en' => $titres_menu['Text_menu3_en']],
            ];
            $url      = 'https://fp.codeonline-info.com/assets/pdf/helpDocument_' . $x_lang . '.pdf';
            $response = (object) ['menuPrincipal' => $tablesmenu, 'sponsors' => $tablesponsors, 'helpDocument' => $url];
            $this->response($response, REST_Controller::HTTP_OK);
        } else {
            $url      = 'https://fp.codeonline-info.com/assets/pdf/helpDocument_' . $x_lang . '.pdf';
            $response = (object) ['sponsors' => [], 'helpDocument' => $url];
            $this->response($response, REST_Controller::HTTP_NOT_FOUND);
        }
    }

    // -----------------------------------------------------------------------
    // GET  notifs
    // -----------------------------------------------------------------------
    public function notifs_get()
    {
        $xlang = $this->input->get_request_header('x-lang');
        switch ($xlang) {
            case 'fr-FR': $x_lang = 'fr'; break;
            case 'en-US': $x_lang = 'en'; break;
            default:      $x_lang = 'fr';
        }

        $Notiftable = [];
        $i          = 0;
        $notifs     = $this->api_model_fp->all_notif_active();
        foreach ($notifs as $notif) {
            $Notiftable[$i] = (object) [
                'idNotif'      => $notif['idNotif'],
                'titreNotif'   => $notif['titre_notif_' . $x_lang],
                'textNotif'    => $notif['texte_notif_' . $x_lang],
                'titreNotifAr' => $notif['titre_notif_ar'],
                'textNotifAr'  => $notif['texte_notif_ar']
            ];
            $i++;
        }

        if (!empty($notifs)) {
            $this->response($Notiftable, REST_Controller::HTTP_OK);
        } else {
            $this->response((object) [], REST_Controller::HTTP_NOT_FOUND);
        }
    }

    // -----------------------------------------------------------------------
    // GET  fiche_produit_marque_categorie_by_brand
    // -----------------------------------------------------------------------
    public function fiche_produit_marque_categorie_by_brand_get()
    {
        $xlang = $this->input->get_request_header('x-lang');
        switch ($xlang) {
            case 'fr-FR': $x_lang = 'fr'; break;
            case 'en-US': $x_lang = 'en'; break;
            default:      $x_lang = 'fr';
        }

        $brands = $this->api_model_fp->fiche_produit_name_brand($this->get('brand'));
        if (!empty($brands)) {
            if (count($brands) == 1) {
                $categories = $this->api_model_fp->marque_categorie_by_brand($this->get('brand'));
                if (count($categories) == 1) {
                    $response[0] = [
                        'brand'      => $brands[0]['nameBrand'],
                        'categories' => [(object) [
                            'name'    => $categories[0]['libelleBrique_' . $x_lang],
                            'name_ar' => $categories[0]['libelleBrique_ar'],
                            'code'    => $categories[0]['codeBrique']
                        ]]
                    ];
                } else {
                    $ctable = [];
                    $j      = 0;
                    foreach ($categories as $categorie) {
                        $ctable[$j] = (object) [
                            'name'    => $categorie['libelleBrique_' . $x_lang],
                            'name_ar' => $categories[0]['libelleBrique_ar'],
                            'code'    => $categorie['codeBrique']
                        ];
                        $j++;
                    }
                    $response[0] = ['brand' => $brands[0]['nameBrand'], 'categories' => $ctable];
                }
            } else {
                $brandtable = [];
                $i = 0;
                foreach ($brands as $brand) {
                    $categories = $this->api_model_fp->marque_categorie_by_brand_ext($brand['nameBrand']);
                    $ctable     = [];
                    $j          = 0;
                    if (count($categories) == 1) {
                        $brandtable[$i] = (object) [
                            'brand'      => $brand['nameBrand'],
                            'categories' => [(object) [
                                'name'    => $categories[0]['libelleBrique_' . $x_lang],
                                'name_ar' => $categories[0]['libelleBrique_ar'],
                                'code'    => $categories[0]['codeBrique']
                            ]]
                        ];
                    } else {
                        foreach ($categories as $categorie) {
                            $ctable[$j] = (object) [
                                'name'    => $categorie['libelleBrique_' . $x_lang],
                                'name_ar' => $categories[0]['libelleBrique_ar'],
                                'code'    => $categorie['codeBrique']
                            ];
                            $j++;
                        }
                        $brandtable[$i] = (object) ['brand' => $brand['nameBrand'], 'categories' => $ctable];
                    }
                    $i++;
                }
                $response = $brandtable;
            }
        } else {
            $hub = $this->registry_fp_brand_categories($this->get('brand'));
            if (!empty($hub)) {
                $this->response($hub, REST_Controller::HTTP_OK);
                return;
            }
            $this->response((object) [], REST_Controller::HTTP_NOT_FOUND);
            return;
        }

        $this->response($response, REST_Controller::HTTP_OK);
    }

    // -----------------------------------------------------------------------
    // GET  fiche_produit_by_brand_category
    // -----------------------------------------------------------------------
    public function fiche_produit_by_brand_category_get()
    {
        $brand        = $this->get('brand');
        $categoryCode = $this->get('categoryCode');
        $page         = $this->get('page');
        $pageSize     = 40;

        $total_fiche_produit = $this->api_model_fp->count_total_fiche_produit_categoryCode_brand($brand, $categoryCode);
        $total               = intval($total_fiche_produit['totalFP']);

        if ($total == 0) {
            $hub = $this->registry_fp_products($brand, $categoryCode, $page);
            if (!empty($hub) && !empty($hub['items'])) { $this->response($hub, REST_Controller::HTTP_OK); return; }
        }

        if ($total <= $pageSize) {
            $FPs = $this->api_model_fp->fiche_produit_categoryCode_brand_sans_limit($brand, $categoryCode);
        } else {
            $start = ($pageSize * $page) - $pageSize;
            $FPs   = $this->api_model_fp->fiche_produit_categoryCode_brand_with_limit($brand, $categoryCode, $start, $pageSize);
        }

        if (!empty($FPs)) {
            // *** FIX: resolve image paths for every product ***
            for ($k = 0; $k < count($FPs); $k++) {
                $FPs[$k]['images'] = $this->_parse_images(
                    is_array($FPs[$k]['images']) ? implode(';', $FPs[$k]['images']) : $FPs[$k]['images']
                );
            }
            $webtable = (object) ['items' => $FPs, 'total' => $total, 'pageSize' => $pageSize];
        } else {
            $webtable = (object) ['items' => [], 'total' => 0, 'pageSize' => $pageSize];
        }

        $this->response($webtable, REST_Controller::HTTP_OK);
    }

    // -----------------------------------------------------------------------
    // GET  highlighted_products
    //
    // Public endpoint for the MOBILE APP home screen's "Produits en vedette"
    // showcase (see fetchHighlightedShowcase() in home.dart).
    //
    // The web app (CatalogueComplet.tsx / server.js) lets an entity request
    // one or more of its own products be "highlighted", and a platform admin
    // (entité 999 or 111) approves or rejects that request from a review
    // modal there. Those requests live in a `product_highlights` table that
    // server.js creates automatically on boot (id_produit, id_entite, status
    // enum('pending','approved','rejected'), reviewed_at, ...).
    //
    // The mobile app never talks to server.js - it only ever calls this PHP
    // API. But since server.js and this API read/write the SAME database,
    // this endpoint can just query `product_highlights` directly, exactly
    // like the web app's own GET /api/public/highlighted-products does, and
    // return it in the shape home.dart expects. No second host, no syncing.
    //
    // Response shape:
    //   { "entities": [
    //       { "id_entite": 42, "name": "Some Company",
    //         "products": [ { "id", "gtin", "brand", "subBrand",
    //                         "productName", "short_libelle", "description",
    //                         "countryOfOrigin", "images": ["https://..."] }, ... ]
    //       }, ...
    //   ] }
    //
    // Only entities with at least one APPROVED product are returned, most
    // recently-approved entity first, each capped to `limit_per_entity`
    // products (GET param, default 4, max 20).
    // -----------------------------------------------------------------------
    public function highlighted_products_get()
    {
        $perEntityLimit = intval($this->get('limit_per_entity'));
        if ($perEntityLimit <= 0) { $perEntityLimit = 4; }
        if ($perEntityLimit > 20) { $perEntityLimit = 20; }

        // Make sure we have a DB connection even though this API's models
        // normally go through api_model_fp - this query doesn't need a
        // model, product_highlights isn't "owned" by this codebase.
        $this->load->database();

        $sql = "
            SELECT ph.id_produit, ph.id_entite, ph.reviewed_at,
                   fp.gtin, fp.brand, fp.subBrand, fp.libelle AS productName,
                   fp.short_libelle, fp.description, fp.countryOfOrigin, fp.images,
                   e.raison_socialle AS entite_name, e.logo AS entite_logo
            FROM product_highlights ph
            JOIN fiche_produit fp ON fp.id = ph.id_produit
            LEFT JOIN Entite e ON e.id_entite = ph.id_entite
            WHERE ph.status = 'approved'
            ORDER BY ph.reviewed_at DESC
        ";

        try {
            $query = $this->db->query($sql);
        } catch (Exception $e) {
            // Most likely cause: product_highlights doesn't exist yet on
            // this DB (server.js creates it on its own boot - make sure the
            // web server has started at least once). Fail quiet so the
            // mobile showcase just stays hidden instead of erroring.
            log_message('error', 'highlighted_products_get: ' . $e->getMessage());
            $this->response((object) ['entities' => []], REST_Controller::HTTP_OK);
            return;
        }

        $rows = $query ? $query->result_array() : [];

        $byEntite = [];
        $order    = [];

        foreach ($rows as $r) {
            $idEntite = $r['id_entite'];

            if (!isset($byEntite[$idEntite])) {
                $byEntite[$idEntite] = [
                    'id_entite'           => $idEntite,
                    'name'                => !empty($r['entite_name']) ? $r['entite_name'] : ('Entité ' . $idEntite),
                    // Absolute URL to the entity's logo, or null - the mobile
                    // app falls back to a name-initial placeholder tile when
                    // this is null (entity never uploaded a logo).
                    'logo'                => $this->_resolve_logo_url($r['entite_logo']),
                    '_latest_reviewed_at' => $r['reviewed_at'],
                    'products'            => [],
                ];
                $order[] = $idEntite;
            }

            if (count($byEntite[$idEntite]['products']) < $perEntityLimit) {
                $byEntite[$idEntite]['products'][] = [
                    'id'              => $r['id_produit'],
                    'gtin'            => $r['gtin'],
                    'brand'           => $r['brand'],
                    'subBrand'        => $r['subBrand'],
                    'productName'     => $r['productName'],
                    'short_libelle'   => $r['short_libelle'],
                    'description'     => $r['description'],
                    'countryOfOrigin' => $r['countryOfOrigin'],
                    // *** Same helper every other endpoint in this file uses
                    // to turn the semicolon-separated `images` column into
                    // absolute URLs (images_base_url / IMAGES_BASE_URL) ***
                    'images'          => $this->_parse_images($r['images']),
                ];
            }
        }

        $entities = array_values($byEntite);

        // Freshest approval leads the carousel (mirrors server.js behaviour).
        usort($entities, function ($a, $b) {
            return strtotime($b['_latest_reviewed_at'] ?: '1970-01-01')
                 - strtotime($a['_latest_reviewed_at'] ?: '1970-01-01');
        });
        foreach ($entities as &$e) {
            unset($e['_latest_reviewed_at']);
        }
        unset($e);

        $this->response((object) ['entities' => $entities], REST_Controller::HTTP_OK);
    }

    // -----------------------------------------------------------------------
    // GET  fiche_produit_by_cader
    // -----------------------------------------------------------------------
    public function fiche_produit_by_cader_get()
    {
        $cader = $this->get('cader');
        $xlang = $this->input->get_request_header('x-lang');
        switch ($xlang) {
            case 'fr-FR': $x_lang = 'fr'; break;
            case 'en-US': $x_lang = 'en'; break;
            default:      $x_lang = 'fr';
        }

        if ($cader != 'Encadre') {
            $segments = $this->api_model_fp->fiche_produit_segment_cader($cader);
        } else {
            $segments = $this->api_model_fp->fiche_produit_segment_art('99000000');
        }

        if (!empty($segments)) {
            $cadertable = [];
            $btable     = [];
            $i          = 0;
            $j          = 0;

            foreach ($segments as $segment) {
                $stable = (object) [
                    'name_fr' => $segment['libelleSegment_' . $x_lang],
                    'name_ar' => $segment['libelleSegment_ar'],
                    'code'    => $segment['codeSegment']
                ];

                if ($cader != 'Encadre') {
                    $categories = $this->api_model_fp->fiche_produit_segment_categorie_cader($cader, $segment['codeSegment']);
                } else {
                    $categories = $this->api_model_fp->fiche_produit_segment_categorie_art('99000000');
                }

                foreach ($categories as $categorie) {
                    if ($cader != 'Encadre') {
                        $FPs = $this->api_model_fp->fiche_produit_by_categorie_cader($cader, $categorie['codeBrique']);
                    } else {
                        $FPs = $this->api_model_fp->fiche_produit_by_categorie_art($categorie['codeBrique']);
                    }

                    // *** FIX: resolve image paths ***
                    for ($k = 0; $k < count($FPs); $k++) {
                        $FPs[$k]['images'] = $this->_parse_images(
                            is_array($FPs[$k]['images']) ? implode(';', $FPs[$k]['images']) : $FPs[$k]['images']
                        );
                    }

                    $btable[$i] = (object) [
                        'name_fr' => $categorie['libelleBrique_' . $x_lang],
                        'name_ar' => $categorie['libelleBrique_ar'],
                        'code'    => $categorie['codeBrique'],
                        'FPs'     => $FPs
                    ];
                    $i++;
                }

                $cadertable[$j] = (object) ['segment' => $stable, 'categories' => $btable];
                $btable         = [];
                $i              = 0;
                $j++;
            }
        } else {
            $this->response((object) [], REST_Controller::HTTP_NOT_FOUND);
            return;
        }

        $this->response($cadertable, REST_Controller::HTTP_OK);
    }

    // -----------------------------------------------------------------------
    // GET  fiche_service_by_id
    // -----------------------------------------------------------------------
    public function fiche_service_by_id_get()
    {
        $xlang = $this->input->get_request_header('x-lang');
        switch ($xlang) {
            case 'fr-FR': $x_lang = 'fr'; break;
            case 'en-US': $x_lang = 'en'; break;
            default:      $x_lang = 'fr';
        }

        $response = $this->api_model_fp->fiche_service_id($this->get('idService'));
        if (!empty($response)) {
            // *** FIX: resolve image paths ***
            $response['images'] = $this->_parse_images(
                is_array($response['images']) ? implode(';', $response['images']) : $response['images']
            );

            if ($response['telephone'] == null) { $response['telephone'] = ''; }
            if ($response['email']     == null) { $response['email']     = ''; }
            if ($response['site']      == null) { $response['site']      = ''; }

            $response['serveur']       = 'local';
            $response['libelleBrique'] = $response['libelleBrique_' . $x_lang];
            unset($response['libelleBrique_fr']);
            unset($response['libelleBrique_en']);

            $response['titreService'] = $response['titreService_' . $x_lang];
            unset($response['titreService_fr']);
            unset($response['titreService_en']);

            $response['texteService'] = $response['texteService_' . $x_lang];
            unset($response['texteService_fr']);
            unset($response['texteService_en']);

            $this->response($response, REST_Controller::HTTP_OK);
        } else {
            $this->response((object) [], REST_Controller::HTTP_NOT_FOUND);
        }
    }

    // -----------------------------------------------------------------------
    // GET  fiche_services_by_categories
    // -----------------------------------------------------------------------
    public function fiche_services_by_categories_get()
    {
        $xlang = $this->input->get_request_header('x-lang');
        switch ($xlang) {
            case 'fr-FR': $x_lang = 'fr'; break;
            case 'en-US': $x_lang = 'en'; break;
            default:      $x_lang = 'fr';
        }

        $segment = $this->api_model_fp->get_segment_service('120000000');
        if (!empty($segment)) {
            $servicetable = [];
            $i            = 0;
            $j            = 0;
            $btable       = [];

            $stable = (object) [
                'libelleSegment'    => $segment['libelleSegment_' . $x_lang],
                'libelleSegment_ar' => $segment['libelleSegment_ar'],
                'codeSegment'       => $segment['codeSegment']
            ];

            $categories = $this->api_model_fp->fiche_service_segment_categorie_service('120000000');
            if (!empty($categories)) {
                foreach ($categories as $categorie) {
                    $FPs = $this->api_model_fp->fiche_service_by_brique($categorie['codeBrique']);

                    // *** FIX: resolve image paths ***
                    for ($k = 0; $k < count($FPs); $k++) {
                        $FPs[$k]['images'] = $this->_parse_images(
                            is_array($FPs[$k]['images']) ? implode(';', $FPs[$k]['images']) : $FPs[$k]['images']
                        );
                        $FPs[$k]['titreService'] = $FPs[$k]['titreService_' . $x_lang];
                        unset($FPs[$k]['titreService_fr']);
                        unset($FPs[$k]['titreService_en']);
                    }

                    $btable[$i] = (object) [
                        'libelleBrique'    => $categorie['libelleBrique_' . $x_lang],
                        'libelleBrique_ar' => $categorie['libelleBrique_ar'],
                        'codeBrique'       => $categorie['codeBrique'],
                        'FPs'              => $FPs
                    ];
                    $i++;
                }
                $servicetable[$j] = (object) ['segment' => $stable, 'categories' => $btable];
            } else {
                $this->response((object) [], REST_Controller::HTTP_NOT_FOUND);
                return;
            }
        } else {
            $this->response((object) [], REST_Controller::HTTP_NOT_FOUND);
            return;
        }

        $this->response($servicetable, REST_Controller::HTTP_OK);
    }

    // -----------------------------------------------------------------------
    // GET  entite_brands
    //
    // Query params: id_entite (required)
    //
    // Distinct brand names this entity actually sells (from fiche_produit,
    // scoped by idEntreprise). This is the entity-scoped equivalent of what
    // a free-text brand search already does in search.dart - the mobile app
    // reuses the SAME existing fiche_produit_marque_categorie_by_brand /
    // fiche_produit_by_brand_category endpoints per brand name returned
    // here, instead of a new segment-based browse - so tapping "Voir tous
    // les produits" on an entity's home showcase card lands on exactly the
    // same brand -> category -> product screens a manual search already
    // uses, just pre-scoped to this entity's own brand(s).
    //
    // Response shape:
    //   { "id_entite": 34, "brands": ["Herbéos", "AutreMarque"] }
    // -----------------------------------------------------------------------
    public function entite_brands_get()
    {
        $idEntite = intval($this->get('id_entite'));
        if ($idEntite <= 0) {
            $this->response((object) ['error' => 'id_entite is required'], REST_Controller::HTTP_BAD_REQUEST);
            return;
        }

        $this->load->database();

        $sql = "
            SELECT DISTINCT fp.brand
            FROM fiche_produit fp
            WHERE fp.idEntreprise = ?
              AND fp.brand IS NOT NULL
              AND fp.brand <> ''
            ORDER BY fp.brand ASC
        ";

        try {
            $query = $this->db->query($sql, [$idEntite]);
        } catch (Exception $e) {
            log_message('error', 'entite_brands_get: ' . $e->getMessage());
            $this->response((object) ['id_entite' => $idEntite, 'brands' => []], REST_Controller::HTTP_OK);
            return;
        }

        $rows   = $query ? $query->result_array() : [];
        $brands = array_values(array_unique(array_map(function ($r) {
            return $r['brand'];
        }, $rows)));

        $this->response((object) ['id_entite' => $idEntite, 'brands' => $brands], REST_Controller::HTTP_OK);
    }

    // -----------------------------------------------------------------------
    // GET  entite_segments
    //
    // Query params: id_entite (required)
    //
    // Lists the GPC segments this entity actually has products in, with a
    // product count per segment - the "tap the entity logo on the home
    // showcase" landing screen (segments grid) is built from this.
    //
    // Classification chain used (mirrors the proven pattern already used
    // elsewhere against this same DB - e.g. the /api/product-sheets-by-sector
    // and /api/segments-by-classe style joins on the web admin side):
    //   fiche_produit.codeClasse -> classegpc.codeClasse
    //   classegpc.codeSeg        -> segmentgpc.codeSegment
    //
    // Response shape:
    //   { "id_entite": 34, "segments": [
    //       { "code": "...", "name_fr": "...", "name_en": "...",
    //         "name_ar": "...", "product_count": 12 }, ...
    //   ] }
    // -----------------------------------------------------------------------
    public function entite_segments_get()
    {
        $idEntite = intval($this->get('id_entite'));
        if ($idEntite <= 0) {
            $this->response((object) ['error' => 'id_entite is required'], REST_Controller::HTTP_BAD_REQUEST);
            return;
        }

        $this->load->database();

        $sql = "
            SELECT c.codeSeg AS codeSegment,
                   s.libelleSegment   AS libelleSegment_fr,
                   s.libelleSegment_e AS libelleSegment_en,
                   s.libelleSegment_a AS libelleSegment_ar,
                   COUNT(DISTINCT fp.id) AS product_count
            FROM fiche_produit fp
            JOIN classegpc c  ON c.codeClasse = fp.codeClasse
            JOIN segmentgpc s ON s.codeSegment = c.codeSeg
            WHERE fp.idEntreprise = ?
              AND c.codeSeg IS NOT NULL
            GROUP BY c.codeSeg, s.libelleSegment, s.libelleSegment_e, s.libelleSegment_a
            ORDER BY s.libelleSegment ASC
        ";

        try {
            $query = $this->db->query($sql, [$idEntite]);
        } catch (Exception $e) {
            log_message('error', 'entite_segments_get: ' . $e->getMessage());
            $this->response((object) ['id_entite' => $idEntite, 'segments' => []], REST_Controller::HTTP_OK);
            return;
        }

        $rows     = $query ? $query->result_array() : [];
        $segments = [];
        foreach ($rows as $r) {
            $segments[] = [
                'code'          => $r['codeSegment'],
                'name_fr'       => $r['libelleSegment_fr'],
                'name_en'       => !empty($r['libelleSegment_en']) ? $r['libelleSegment_en'] : $r['libelleSegment_fr'],
                'name_ar'       => $r['libelleSegment_ar'],
                'product_count' => intval($r['product_count']),
            ];
        }

        $this->response((object) ['id_entite' => $idEntite, 'segments' => $segments], REST_Controller::HTTP_OK);
    }

    // -----------------------------------------------------------------------
    // GET  entite_products_by_segment
    //
    // Query params: id_entite (required), codeSegment (required)
    //
    // All of this entity's products that fall inside the given GPC segment -
    // feeds the product grid once the user drills into a segment from the
    // entite_segments_get() screen.
    //
    // Response shape mirrors highlighted_products_get()'s per-product shape
    // so the mobile side can reuse the same product-card widget.
    // -----------------------------------------------------------------------
    public function entite_products_by_segment_get()
    {
        $idEntite    = intval($this->get('id_entite'));
        $codeSegment = $this->get('codeSegment');

        if ($idEntite <= 0 || empty($codeSegment)) {
            $this->response((object) ['error' => 'id_entite and codeSegment are required'], REST_Controller::HTTP_BAD_REQUEST);
            return;
        }

        $this->load->database();

        $sql = "
            SELECT fp.id, fp.gtin, fp.brand, fp.subBrand, fp.libelle AS productName,
                   fp.short_libelle, fp.description, fp.countryOfOrigin, fp.images
            FROM fiche_produit fp
            JOIN classegpc c ON c.codeClasse = fp.codeClasse
            WHERE fp.idEntreprise = ? AND c.codeSeg = ?
            ORDER BY fp.libelle ASC
        ";

        try {
            $query = $this->db->query($sql, [$idEntite, $codeSegment]);
        } catch (Exception $e) {
            log_message('error', 'entite_products_by_segment_get: ' . $e->getMessage());
            $this->response((object) ['id_entite' => $idEntite, 'codeSegment' => $codeSegment, 'products' => []], REST_Controller::HTTP_OK);
            return;
        }

        $rows     = $query ? $query->result_array() : [];
        $products = [];
        foreach ($rows as $r) {
            $products[] = [
                'id'              => $r['id'],
                'gtin'            => $r['gtin'],
                'brand'           => $r['brand'],
                'subBrand'        => $r['subBrand'],
                'productName'     => $r['productName'],
                'short_libelle'   => $r['short_libelle'],
                'description'     => $r['description'],
                'countryOfOrigin' => $r['countryOfOrigin'],
                'images'          => $this->_parse_images($r['images']),
            ];
        }

        $this->response((object) [
            'id_entite'   => $idEntite,
            'codeSegment' => $codeSegment,
            'products'    => $products,
        ], REST_Controller::HTTP_OK);
    }

    // -----------------------------------------------------------------------
    // GET  caracteristiques_search
    //
    // Mobile "same search bar" integration: the app's existing search bar
    // (search.dart) already searches brands via
    // fiche_produit_marque_categorie_by_brand_get(); this endpoint lets it
    // ALSO surface "caracteristiques" fiches (products/services that don't
    // fit a normal fiche produit) matching the exact same typed text -
    // identification, brand, utilite or code_identifiant - so the mobile
    // side can merge both results into one list. No new/separate search UI
    // is introduced by this - it's called in parallel with the existing
    // brand search, from the same bar.
    //
    // Query params: q (required)
    //
    // Reads the SAME MySQL tables server.js owns/creates
    // (caracteristiques / caracteristiques_illustrations / Entite) via
    // $this->db - the mobile app never calls server.js directly.
    //
    // Response shape:
    //   { "caracteristiques": [
    //       { "id_carac": 12, "id_entite": 34, "identification": "...",
    //         "brand": "...", "code_identifiant": "619340007",
    //         "nature": "...", "utilite": "...", "entite_name": "...",
    //         "thumbnail": "https://.../images/caracteristiques/xxx.jpg" | null }, ...
    //   ] }
    // -----------------------------------------------------------------------
    public function caracteristiques_search_get()
    {
        $q = trim((string) $this->get('q'));
        if ($q === '') {
            $this->response((object) ['caracteristiques' => []], REST_Controller::HTTP_OK);
            return;
        }

        $this->load->database();

        $like = '%' . $q . '%';

        // Mobile only ever shows a caracteristique fiche when BOTH are true:
        //  - nature = 'fiche permanente' ('fiche occasionnelle' never shows
        //    on mobile at all, approved or not - it stays web-admin only).
        //  - approval_status = 'approved' (an admin has reviewed it, same
        //    as fiche produit's own review/approval flow).
        $sql = "
            SELECT c.id_carac, c.id_entite, c.identification, c.brand,
                   c.code_identifiant, c.nature, c.utilite,
                   e.raison_socialle AS entite_name
            FROM caracteristiques c
            LEFT JOIN Entite e ON e.id_entite = c.id_entite
            WHERE c.nature = 'fiche permanente'
              AND c.approval_status = 'approved'
              AND (c.identification LIKE ? OR c.brand LIKE ? OR c.utilite LIKE ? OR c.code_identifiant LIKE ?)
            ORDER BY c.updated_at DESC
            LIMIT 30
        ";

        try {
            $query = $this->db->query($sql, [$like, $like, $like, $like]);
        } catch (Exception $e) {
            // Fail quiet (e.g. the caracteristiques table/columns aren't on
            // this DB yet because server.js hasn't booted once since this
            // feature was deployed) - brand search on the mobile side keeps
            // working regardless.
            log_message('error', 'caracteristiques_search_get: ' . $e->getMessage());
            $this->response((object) ['caracteristiques' => []], REST_Controller::HTTP_OK);
            return;
        }

        $rows = $query ? $query->result_array() : [];

        // One thumbnail per fiche (first image illustration), fetched in a
        // single follow-up query rather than N+1 queries.
        $thumbnails = [];
        if (!empty($rows)) {
            $ids          = array_map(function ($r) { return $r['id_carac']; }, $rows);
            $placeholders = implode(',', array_fill(0, count($ids), '?'));
            try {
                $thumbQuery = $this->db->query(
                    "SELECT id_carac, url FROM caracteristiques_illustrations WHERE id_carac IN ($placeholders) AND type = 'image' ORDER BY id ASC",
                    $ids
                );
                foreach ($thumbQuery->result_array() as $t) {
                    if (!isset($thumbnails[$t['id_carac']])) {
                        $thumbnails[$t['id_carac']] = $t['url'];
                    }
                }
            } catch (Exception $e) {
                log_message('error', 'caracteristiques_search_get thumbnails: ' . $e->getMessage());
            }
        }

        $results = [];
        foreach ($rows as $r) {
            $results[] = [
                'id_carac'         => $r['id_carac'],
                'id_entite'        => $r['id_entite'],
                'identification'   => $r['identification'],
                'brand'            => $r['brand'],
                'code_identifiant' => $r['code_identifiant'],
                'nature'           => $r['nature'],
                'utilite'          => $r['utilite'],
                'entite_name'      => !empty($r['entite_name']) ? $r['entite_name'] : null,
                'thumbnail'        => isset($thumbnails[$r['id_carac']])
                    ? $this->_resolve_image_url($thumbnails[$r['id_carac']])
                    : null,
            ];
        }

        $this->response((object) ['caracteristiques' => $results], REST_Controller::HTTP_OK);
    }

    // -----------------------------------------------------------------------
    // GET  caracteristique_by_id
    //
    // Full detail for one caracteristique fiche: the row itself, its
    // elements techniques, and its illustrations (image/video URLs resolved
    // to absolute). Feeds the mobile detail screen opened when a search
    // result from caracteristiques_search_get() is tapped.
    //
    // Query params: id_carac (required)
    // -----------------------------------------------------------------------
    public function caracteristique_by_id_get()
    {
        $idCarac = intval($this->get('id_carac'));
        if ($idCarac <= 0) {
            $this->response((object) ['error' => 'id_carac is required'], REST_Controller::HTTP_BAD_REQUEST);
            return;
        }

        $this->load->database();

        try {
            // Same mobile visibility gate as caracteristiques_search_get()
            // above: only an approved 'fiche permanente' can be opened from
            // mobile - a direct id_carac guess can't bypass that either.
            $caracQuery = $this->db->query(
                "SELECT c.*, e.raison_socialle AS entite_name FROM caracteristiques c LEFT JOIN Entite e ON e.id_entite = c.id_entite WHERE c.id_carac = ? AND c.nature = 'fiche permanente' AND c.approval_status = 'approved'",
                [$idCarac]
            );
        } catch (Exception $e) {
            log_message('error', 'caracteristique_by_id_get: ' . $e->getMessage());
            $this->response((object) ['error' => 'not_found'], REST_Controller::HTTP_NOT_FOUND);
            return;
        }

        $rows = $caracQuery ? $caracQuery->result_array() : [];
        if (empty($rows)) {
            $this->response((object) ['error' => 'not_found'], REST_Controller::HTTP_NOT_FOUND);
            return;
        }
        $carac = $rows[0];

        $elements = [];
        try {
            $elementsQuery = $this->db->query(
                "SELECT nom_element, type_element, options_element, valeur_default FROM caracteristiques_elements WHERE id_carac = ?",
                [$idCarac]
            );
            foreach ($elementsQuery->result_array() as $el) {
                $options = null;
                if (!empty($el['options_element'])) {
                    $decoded = json_decode($el['options_element'], true);
                    $options = (json_last_error() === JSON_ERROR_NONE) ? $decoded : $el['options_element'];
                }
                $elements[] = [
                    'nom'          => $el['nom_element'],
                    'type'         => $el['type_element'],
                    'options'      => $options,
                    'defaultValue' => $el['valeur_default'],
                ];
            }
        } catch (Exception $e) {
            log_message('error', 'caracteristique_by_id_get elements: ' . $e->getMessage());
        }

        $illustrations = [];
        try {
            $illustrationsQuery = $this->db->query(
                "SELECT filename, type, url FROM caracteristiques_illustrations WHERE id_carac = ?",
                [$idCarac]
            );
            foreach ($illustrationsQuery->result_array() as $il) {
                $illustrations[] = [
                    'filename' => $il['filename'],
                    'type'     => $il['type'],
                    'url'      => $this->_resolve_image_url($il['url']),
                ];
            }
        } catch (Exception $e) {
            log_message('error', 'caracteristique_by_id_get illustrations: ' . $e->getMessage());
        }

        $this->response((object) [
            'carac' => [
                'id_carac'         => $carac['id_carac'],
                'id_entite'        => $carac['id_entite'],
                'identification'   => $carac['identification'],
                'brand'            => $carac['brand'],
                'code_identifiant' => $carac['code_identifiant'],
                'description_fr'   => $carac['description_fr'],
                'description_en'   => $carac['description_en'],
                'description_ar'   => $carac['description_ar'],
                'nature'           => $carac['nature'],
                'utilite'          => $carac['utilite'],
                'date_lancement'   => $carac['date_lancement'],
                'entite_name'      => !empty($carac['entite_name']) ? $carac['entite_name'] : null,
            ],
            'elements'      => $elements,
            'illustrations' => $illustrations,
        ], REST_Controller::HTTP_OK);
    }
}